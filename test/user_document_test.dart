/// Tests for the users/{uid} bootstrap.
///
/// The gap this closes: only email/password signup created the user document.
/// `AuthService.signInWithGoogle` and `signInWithApple` did not, and the FCM
/// token write that would otherwise create it is skipped on web and whenever
/// the user declines the notification prompt. Those users reached the home
/// screen with no document, which is what let the dot-notation fallback in
/// StreakService corrupt their streak permanently.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/screens/service_backend.dart';
import 'package:binary/screens/user_document.dart';

const uid = 'test-uid';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: uid);
  });

  tearDown(ServiceBackend.reset);

  DocumentReference<Map<String, dynamic>> userDoc() =>
      db.collection('users').doc(uid);

  Future<Map<String, dynamic>> read() async =>
      (await userDoc().get()).data() ?? {};

  test('creates the document when none exists', () async {
    expect((await userDoc().get()).exists, isFalse);

    await ensureUserDocument(displayName: 'Ada Lovelace');

    final data = await read();
    expect(data['name'], 'Ada Lovelace');
    expect(data['createdAt'], isNotNull);
    expect(data['enrolments'], isEmpty);
  });

  test('creates it even with no display name to use', () async {
    // Apple only sends a name on the very first sign-in, and users can decline
    // to share it at all.
    await ensureUserDocument();

    final data = await read();
    expect((await userDoc().get()).exists, isTrue);
    expect(data['createdAt'], isNotNull);
    expect(data.containsKey('name'), isFalse);
  });

  test('writes no entitlement fields, so firestore.rules permits the create',
      () async {
    // `allow create: if isOwner(uid) && noEntitlementsOnCreate()` — a single
    // entitlement key here would make every social sign-in fail the rules.
    await ensureUserDocument(displayName: 'Ada');

    const entitlementFields = [
      'subscriptionPlan',
      'subscriptionUpdatedAt',
      'subscribedCourseId',
      'bundleCourseIds',
      'trialCourseId',
      'trialExpiry',
      'trialStartedAt',
      'hasUsedTrial',
      'role',
      'isAdmin',
    ];
    final keys = (await read()).keys.toSet();
    for (final field in entitlementFields) {
      expect(keys, isNot(contains(field)), reason: '$field must be server-only');
    }
  });

  group('an existing document', () {
    test('is not clobbered', () async {
      await userDoc().set({
        'name': 'Existing Name',
        'goal': 'Pass the exam',
        'createdAt': Timestamp.now(),
        'enrolments': {'net-pro': true},
        'lessonsCompleted': 12,
      });

      await ensureUserDocument(displayName: 'Google Display Name');

      final data = await read();
      expect(data['name'], 'Existing Name',
          reason: 'a user who renamed themselves must not be reset');
      expect(data['goal'], 'Pass the exam');
      expect(data['enrolments'], {'net-pro': true});
      expect(data['lessonsCompleted'], 12);
    });

    test('keeps its streak and progress intact', () async {
      await userDoc().set({
        'createdAt': Timestamp.now(),
        'streak': {'current': 9, 'longest': 14},
        'quizzesPassed': 5,
      });

      await ensureUserDocument(displayName: 'Ada');

      final data = await read();
      expect(data['streak'], {'current': 9, 'longest': 14});
      expect(data['quizzesPassed'], 5);
    });

    test('backfills a missing name', () async {
      await userDoc().set({'createdAt': Timestamp.now()});

      await ensureUserDocument(displayName: 'Ada');
      expect((await read())['name'], 'Ada');
    });

    test('backfills nothing when there is no name to write', () async {
      await userDoc().set({'createdAt': Timestamp.now()});

      await ensureUserDocument();
      expect((await read()).containsKey('name'), isFalse);
    });

    test('an empty display name is treated as no name', () async {
      await ensureUserDocument(displayName: '');
      expect((await read()).containsKey('name'), isFalse);
    });
  });

  test('a partial document left by the old bug is completed', () async {
    // A user whose only write was the FCM token has a document with no
    // createdAt. It should still get bootstrapped rather than skipped.
    await userDoc().set({'fcmToken': 'abc123'});

    await ensureUserDocument(displayName: 'Ada');

    final data = await read();
    expect(data['createdAt'], isNotNull);
    expect(data['enrolments'], isEmpty);
    expect(data['fcmToken'], 'abc123');
  });

  test('does nothing when signed out', () async {
    ServiceBackend.useFake(db, uid: null);
    await ensureUserDocument(displayName: 'Ada');
    expect((await userDoc().get()).exists, isFalse);
  });

  test('is safe to call repeatedly', () async {
    await ensureUserDocument(displayName: 'Ada');
    final first = (await read())['createdAt'];

    await ensureUserDocument(displayName: 'Ada');
    await ensureUserDocument(displayName: 'Someone Else');

    final data = await read();
    expect(data['name'], 'Ada');
    expect(data['createdAt'], first, reason: 'createdAt must not be rewritten');
  });
}
