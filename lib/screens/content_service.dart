import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../content_source.dart';
import '../course_content.dart';
import 'offline_service.dart';
import 'service_backend.dart';
import 'subscription_service.dart';

class ContentService {
  ContentService._();

  static Future<ContentResult<Map<String, String>>> flashcards(
    String courseId,
    String moduleId, {
    bool downloadedOnly = false,
  }) async {
    final uid = ServiceBackend.uid;
    try {
      if (uid == null ||
          !await SubscriptionService.canAccessModule(
              courseId: courseId,
              moduleId: moduleId,
              cachedOnly: downloadedOnly)) {
        return const ContentResult([], ContentOrigin.unavailable);
      }
      if (downloadedOnly) {
        final cached =
            await OfflineService.loadCachedFlashcards(courseId, moduleId);
        if (ServiceBackend.uid != uid || cached == null || cached.isEmpty) {
          return const ContentResult([], ContentOrigin.unavailable);
        }
        return ContentResult(cached, ContentOrigin.cached);
      }
      final snapshot = await ServiceBackend.db
          .collection('courses')
          .doc(courseId)
          .collection('modules')
          .doc(moduleId)
          .collection('flashcards')
          .orderBy('order')
          .get()
          .timeout(const Duration(seconds: 12));
      final cards = parseFlashcards(snapshot.docs.map((doc) => doc.data()));
      if (ServiceBackend.uid != uid) {
        return const ContentResult([], ContentOrigin.unavailable);
      }
      if (cards.isNotEmpty) {
        return ContentResult(
            cards,
            snapshot.metadata.isFromCache
                ? ContentOrigin.cached
                : ContentOrigin.live);
      }
      // An authoritative empty response must not resurrect removed content.
      if (!snapshot.metadata.isFromCache) {
        return const ContentResult([], ContentOrigin.unavailable);
      }
    } on FirebaseException catch (error) {
      debugPrint('Lesson content: ${error.code}');
      if (error.code != 'unavailable' && error.code != 'deadline-exceeded') {
        return const ContentResult([], ContentOrigin.unavailable);
      }
    } on FormatException {
      return const ContentResult([], ContentOrigin.unavailable);
    } catch (error) {
      debugPrint('Lesson content could not load: $error');
    }
    if (ServiceBackend.uid != uid) {
      return const ContentResult([], ContentOrigin.unavailable);
    }
    final cached =
        await OfflineService.loadCachedFlashcards(courseId, moduleId);
    if (cached != null && cached.isNotEmpty) {
      return ContentResult(cached, ContentOrigin.cached);
    }
    return const ContentResult([], ContentOrigin.unavailable);
  }

  static Future<ContentResult<Map<String, dynamic>>> quiz(
    String courseId,
    String moduleId,
  ) async {
    final uid = ServiceBackend.uid;
    try {
      if (uid == null ||
          !await SubscriptionService.canAccessModule(
              courseId: courseId, moduleId: moduleId)) {
        return const ContentResult([], ContentOrigin.unavailable);
      }
      final snapshot = await ServiceBackend.db
          .collection('courses')
          .doc(courseId)
          .collection('modules')
          .doc(moduleId)
          .collection('quiz')
          .orderBy('order')
          .get()
          .timeout(const Duration(seconds: 12));
      final questions =
          parseQuizQuestions(snapshot.docs.map((doc) => doc.data()));
      if (ServiceBackend.uid != uid) {
        return const ContentResult([], ContentOrigin.unavailable);
      }
      return ContentResult(
          questions,
          questions.isEmpty
              ? ContentOrigin.unavailable
              : snapshot.metadata.isFromCache
                  ? ContentOrigin.cached
                  : ContentOrigin.live);
    } catch (error) {
      debugPrint('Quiz content could not load: $error');
      return const ContentResult([], ContentOrigin.unavailable);
    }
  }
}
