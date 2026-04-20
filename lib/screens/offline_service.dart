import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages offline caching of flashcard lesson content.
/// Data is stored as JSON in SharedPreferences keyed by courseId + moduleId.
class OfflineService {
  static const _prefix = 'offline_flashcards';
  static const _downloadedCoursesKey = 'offline_downloaded_courses';

  // ── Check if a course has been downloaded ─────────────────────────────────
  static Future<bool> isCourseDownloaded(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloaded = prefs.getStringList(_downloadedCoursesKey) ?? [];
      return downloaded.contains(courseId);
    } catch (_) {
      return false;
    }
  }

  // ── Get list of all downloaded course IDs ─────────────────────────────────
  static Future<List<String>> getDownloadedCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_downloadedCoursesKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  // ── Download all modules for a course ─────────────────────────────────────
  /// Returns the number of modules successfully cached.
  static Future<int> downloadCourse({
    required String courseId,
    required List<Map<String, dynamic>> modules,
    void Function(int done, int total)? onProgress,
  }) async {
    if (kIsWeb) return 0;

    int saved = 0;
    final prefs = await SharedPreferences.getInstance();

    for (int i = 0; i < modules.length; i++) {
      final module = modules[i];
      final moduleId = module['id'] as String;

      try {
        // Try fetching from Firestore first
        final snap = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .collection('modules')
            .doc(moduleId)
            .collection('flashcards')
            .orderBy('order')
            .get();

        List<Map<String, dynamic>> cards;

        if (snap.docs.isNotEmpty) {
          cards = snap.docs.map((doc) {
            final data = doc.data();
            return {
              'term': (data['question'] ?? '').toString(),
              'definition': (data['answer'] ?? '').toString(),
              'label': 'Flashcard',
              'example': (data['example'] ?? '').toString(),
            };
          }).toList();
        } else {
          // Nothing in Firestore — mark as empty so we know it was attempted
          cards = [];
        }

        // Save to SharedPreferences
        final key = '${_prefix}_${courseId}_$moduleId';
        await prefs.setString(key, jsonEncode(cards));
        saved++;
      } catch (e) {
        debugPrint('OfflineService: failed to cache $courseId/$moduleId: $e');
      }

      onProgress?.call(i + 1, modules.length);
    }

    // Mark course as downloaded if at least some modules saved
    if (saved > 0) {
      final downloaded = prefs.getStringList(_downloadedCoursesKey) ?? [];
      if (!downloaded.contains(courseId)) {
        downloaded.add(courseId);
        await prefs.setStringList(_downloadedCoursesKey, downloaded);
      }
    }

    return saved;
  }

  // ── Load cached flashcards for a module ───────────────────────────────────
  /// Returns null if not cached.
  static Future<List<Map<String, String>>?> loadCachedFlashcards(
    String courseId,
    String moduleId,
  ) async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_prefix}_${courseId}_$moduleId';
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Map<String, String>.from(
              (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Delete a downloaded course ────────────────────────────────────────────
  static Future<void> deleteCourse({
    required String courseId,
    required List<String> moduleIds,
  }) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final moduleId in moduleIds) {
        final key = '${_prefix}_${courseId}_$moduleId';
        await prefs.remove(key);
      }

      final downloaded = prefs.getStringList(_downloadedCoursesKey) ?? [];
      downloaded.remove(courseId);
      await prefs.setStringList(_downloadedCoursesKey, downloaded);
    } catch (e) {
      debugPrint('OfflineService: failed to delete $courseId: $e');
    }
  }

  // ── Get total cached size estimate (number of cards) ─────────────────────
  static Future<int> getCachedCardCount(String courseId) async {
    if (kIsWeb) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      int total = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith('${_prefix}_$courseId')) {
          final raw = prefs.getString(key);
          if (raw != null) {
            final list = jsonDecode(raw) as List<dynamic>;
            total += list.length;
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
