import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'service_backend.dart';

/// Create `users/{uid}` if it does not exist yet.
///
/// Only `signup_screen.dart` (email/password) ever created this document.
/// Google and Apple sign-in did not, and the FCM token write that would
/// otherwise have created it is skipped on web and whenever the user declines
/// the notification prompt. A social-sign-in user could therefore reach the
/// home screen with no document at all, and every service that writes to it
/// had to cope with that — see the dot-notation fallback bug fixed in
/// `service_backend.dart`, which silently froze their streak.
///
/// Fixing the fallback stopped the corruption. This closes the gap that
/// produced it, so the document exists from the first sign-in like it does for
/// every email/password user.
///
/// Deliberately conservative:
///   * `SetOptions(merge: true)` — never clobbers an existing profile.
///   * Writes `name` only when the document has none, so a user who renamed
///     themselves in-app is not reset to their Apple/Google display name on
///     the next sign-in.
///   * Writes **no entitlement fields**. `firestore.rules` allows this create
///     precisely because `noEntitlementsOnCreate()` passes; adding one here
///     would make every social sign-in fail the rules check.
Future<void> ensureUserDocument({String? displayName}) async {
  final uid = ServiceBackend.uid;
  if (uid == null) return;

  try {
    final doc = ServiceBackend.db.collection('users').doc(uid);
    final snap = await doc.get();
    final data = snap.data();

    if (snap.exists && (data?['createdAt'] != null)) {
      // Already bootstrapped. Backfill a missing name, nothing else.
      final hasName = (data?['name'] as String?)?.isNotEmpty ?? false;
      if (!hasName && (displayName?.isNotEmpty ?? false)) {
        await doc.set({'name': displayName}, SetOptions(merge: true));
      }
      return;
    }

    await doc.set({
      if (displayName?.isNotEmpty ?? false) 'name': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'enrolments': <String, dynamic>{},
    }, SetOptions(merge: true));
  } catch (e) {
    // Non-fatal. The services all tolerate a missing document; this is a
    // bootstrap, not a gate on signing in.
    debugPrint('ensureUserDocument failed: $e');
  }
}
