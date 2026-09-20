import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../course_content.dart';
import 'service_backend.dart';

/// Complete downloads are committed in one write. A failed refresh leaves the
/// previous copy intact, and each account has its own storage namespace.
class OfflineService {
  static String _prefix(String uid) =>
      'offline_course_v2_${Uri.encodeComponent(uid)}_';
  static String _key(String uid, String courseId) =>
      '${_prefix(uid)}${Uri.encodeComponent(courseId)}';

  static Future<Map<String, dynamic>?> _read(
      String uid, String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid, courseId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['modules'] is! List ||
          decoded['flashcards'] is! Map) {
        return null;
      }
      final modules = decoded['modules'] as List;
      final cards = decoded['flashcards'] as Map;
      final ids = <String>{};
      if (modules.isEmpty || cards.length != modules.length) return null;
      for (final module in modules) {
        if (module is! Map ||
            module['id'] is! String ||
            (module['id'] as String).isEmpty ||
            module['title'] is! String ||
            module['order'] is! num ||
            !ids.add(module['id'] as String)) {
          return null;
        }
        final lesson = cards[module['id']];
        if (lesson is! List || lesson.isEmpty) return null;
        for (final card in lesson) {
          if (card is! Map ||
              card.values.any((value) => value is! String) ||
              (card['term'] as String? ?? '').trim().isEmpty ||
              (card['definition'] as String? ?? '').trim().isEmpty) {
            return null;
          }
        }
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isCourseDownloaded(String courseId) async {
    final uid = ServiceBackend.uid;
    return uid != null &&
        await _read(uid, courseId) != null &&
        ServiceBackend.uid == uid;
  }

  static Future<List<String>> getDownloadedCourses() async {
    final uid = ServiceBackend.uid;
    if (uid == null) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = _prefix(uid);
      final ids = <String>[];
      for (final key
          in prefs.getKeys().where((key) => key.startsWith(prefix))) {
        final id = Uri.decodeComponent(key.substring(prefix.length));
        if (await _read(uid, id) != null) ids.add(id);
      }
      return ServiceBackend.uid == uid ? (ids..sort()) : [];
    } catch (_) {
      return [];
    }
  }

  /// Returns the full module count on success, zero on an incomplete download.
  /// Empty or invalid content is never advertised as available offline.
  static Future<int> downloadCourse({
    required String courseId,
    required List<Map<String, dynamic>> modules,
    void Function(int done, int total)? onProgress,
  }) async {
    final uid = ServiceBackend.uid;
    if (uid == null || modules.isEmpty) return 0;
    final db = ServiceBackend.db;
    final cards = <String, List<Map<String, String>>>{};
    final metadata = <Map<String, dynamic>>[];
    try {
      for (var i = 0; i < modules.length; i++) {
        if (ServiceBackend.uid != uid) return 0;
        final module = modules[i];
        final moduleId = module['id'];
        if (moduleId is! String ||
            moduleId.isEmpty ||
            cards.containsKey(moduleId)) {
          return 0;
        }
        final snapshot = await db
            .collection('courses')
            .doc(courseId)
            .collection('modules')
            .doc(moduleId)
            .collection('flashcards')
            .orderBy('order')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 15));
        final parsed = parseFlashcards(snapshot.docs.map((doc) => doc.data()));
        if (parsed.isEmpty) return 0;
        cards[moduleId] = parsed;
        metadata.add({
          'id': moduleId,
          'title':
              module['title'] is String ? module['title'] : 'Lesson ${i + 1}',
          'order': module['order'] is num ? module['order'] : i + 1,
        });
        onProgress?.call(i + 1, modules.length);
      }
      if (ServiceBackend.uid != uid) return 0;
      final prefs = await SharedPreferences.getInstance();
      if (ServiceBackend.uid != uid) return 0;
      final saved = await prefs.setString(
          _key(uid, courseId),
          jsonEncode({
            'modules': metadata,
            'flashcards': cards,
          }));
      return saved ? modules.length : 0;
    } catch (error) {
      debugPrint('Offline download failed for $courseId: $error');
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> loadCachedModules(
      String courseId) async {
    final uid = ServiceBackend.uid;
    if (uid == null) return [];
    final data = await _read(uid, courseId);
    if (ServiceBackend.uid != uid) return [];
    return (data?['modules'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, String>>?> loadCachedFlashcards(
    String courseId,
    String moduleId,
  ) async {
    final uid = ServiceBackend.uid;
    if (uid == null) return null;
    try {
      final data = await _read(uid, courseId);
      final list = (data?['flashcards'] as Map?)?[moduleId];
      if (list is! List || list.isEmpty) return null;
      final cards =
          list.map((item) => Map<String, String>.from(item as Map)).toList();
      if (cards.any((card) =>
          (card['term'] ?? '').trim().isEmpty ||
          (card['definition'] ?? '').trim().isEmpty)) {
        return null;
      }
      return ServiceBackend.uid == uid ? cards : null;
    } catch (_) {
      return null;
    }
  }

  /// Removal uses the local manifest, so it works without a network connection.
  static Future<void> deleteCourse({
    required String courseId,
    List<String> moduleIds = const [],
  }) async {
    final uid = ServiceBackend.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key(uid, courseId))) {
      throw StateError('Could not remove download');
    }
  }

  static Future<int> getCachedCardCount(String courseId) async {
    final uid = ServiceBackend.uid;
    if (uid == null) return 0;
    final data = await _read(uid, courseId);
    final cards = data?['flashcards'] as Map?;
    return cards?.values
            .whereType<List>()
            .fold<int>(0, (total, list) => total + list.length) ??
        0;
  }

  static Future<void> clearForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((key) => key.startsWith(_prefix(uid)))) {
      await prefs.remove(key);
    }
  }
}
