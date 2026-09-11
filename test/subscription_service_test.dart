/// Tests for the access decision in [SubscriptionService].
///
/// This is the code path that a paywall bypass came through once: access used
/// to be decided by reading `users/{uid}.subscriptionPlan`, a document the
/// client can write, so any signed-in user could grant themselves the whole
/// catalogue. Entitlement fields are now written only by the Cloud Functions
/// webhook and locked down in firestore.rules — the client merely *reads* the
/// server's answer. These tests pin that reading.
///
/// SCOPE NOTE: when Firestore reports no plan at all, the real code falls back
/// to a live RevenueCat lookup. The RevenueCat SDK is a platform channel with
/// no implementation in the Dart test VM, so that branch cannot be exercised
/// here; it throws and is caught, which is why a no-plan user reads as denied.
/// The tests below therefore prove "Firestore says X → decision Y", not the
/// store-fallback behaviour. See docs/SECURITY.md.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary/screens/service_backend.dart';
import 'package:binary/screens/subscription_service.dart';

const uid = 'test-uid';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: uid);
  });

  tearDown(ServiceBackend.reset);

  Future<void> seed(Map<String, dynamic> data) =>
      db.collection('users').doc(uid).set(data, SetOptions(merge: true));

  Timestamp inHours(int h) =>
      Timestamp.fromDate(DateTime.now().add(Duration(hours: h)));

  group('canAccessCourse — plan "all"', () {
    test('unlocks any course', () async {
      await seed({'subscriptionPlan': 'all'});
      expect(await SubscriptionService.canAccessCourse('net-pro'), isTrue);
      expect(await SubscriptionService.canAccessCourse('anything'), isTrue);
    });
  });

  group('canAccessCourse — plan "bundle4"', () {
    test('unlocks a course named in the bundle', () async {
      await seed({
        'subscriptionPlan': 'bundle4',
        'bundleCourseIds': ['a', 'b', 'c', 'd'],
      });
      expect(await SubscriptionService.canAccessCourse('c'), isTrue);
    });

    test('denies a course outside the bundle', () async {
      await seed({
        'subscriptionPlan': 'bundle4',
        'bundleCourseIds': ['a', 'b', 'c', 'd'],
      });
      expect(await SubscriptionService.canAccessCourse('e'), isFalse);
    });

    test('denies everything when the bundle list is missing', () async {
      // A webhook that set the plan but not the course list must fail closed.
      await seed({'subscriptionPlan': 'bundle4'});
      expect(await SubscriptionService.canAccessCourse('a'), isFalse);
    });
  });

  group('canAccessCourse — plan "single"', () {
    test('unlocks exactly the purchased course', () async {
      await seed({
        'subscriptionPlan': 'single',
        'subscribedCourseId': 'net-pro',
      });
      expect(await SubscriptionService.canAccessCourse('net-pro'), isTrue);
    });

    test('denies any other course', () async {
      await seed({
        'subscriptionPlan': 'single',
        'subscribedCourseId': 'net-pro',
      });
      expect(await SubscriptionService.canAccessCourse('cloud-fun'), isFalse);
    });
  });

  group('canAccessCourse — trial', () {
    test('an unexpired trial unlocks its course', () async {
      await seed({
        'trialCourseId': 'net-pro',
        'trialExpiry': inHours(24),
      });
      expect(await SubscriptionService.canAccessCourse('net-pro'), isTrue);
    });

    test('an expired trial does not', () async {
      await seed({
        'trialCourseId': 'net-pro',
        'trialExpiry': inHours(-1),
      });
      expect(await SubscriptionService.canAccessCourse('net-pro'), isFalse);
    });

    test('a trial on one course does not unlock another', () async {
      await seed({
        'trialCourseId': 'net-pro',
        'trialExpiry': inHours(24),
      });
      expect(await SubscriptionService.canAccessCourse('cloud-fun'), isFalse);
    });
  });

  group('canAccessCourse — denial paths', () {
    test('a user with no document is denied', () async {
      expect(await SubscriptionService.canAccessCourse('net-pro'), isFalse);
    });

    test('a signed-out user is denied without reading anything', () async {
      ServiceBackend.useFake(db, uid: null);
      expect(await SubscriptionService.canAccessCourse('net-pro'), isFalse);
    });

    test('a self-granted plan value the server never writes is denied', () async {
      // Defence in depth. firestore.rules is what actually stops the client
      // writing this field; if a value ever did land, an unrecognised plan
      // string must not be treated as access.
      await seed({'subscriptionPlan': 'premium-hacker'});
      expect(await SubscriptionService.canAccessCourse('net-pro'), isFalse);
    });
  });

  group('canAccessCourse — documented quirk', () {
    test('a bundle plan short-circuits before the trial is considered', () {
      // Pinning current behaviour, not endorsing it: the bundle4 branch
      // returns false for a course outside the bundle without ever reaching
      // the trial check below it. A bundle4 owner who also started a trial on
      // a fifth course is therefore locked out of that trial.
      return seed({
        'subscriptionPlan': 'bundle4',
        'bundleCourseIds': ['a', 'b', 'c', 'd'],
        'trialCourseId': 'e',
        'trialExpiry': inHours(24),
      }).then((_) async {
        expect(await SubscriptionService.canAccessCourse('e'), isFalse);
      });
    });
  });

  group('free preview module', () {
    test('accepts both spellings the content is seeded with', () {
      // The seed scripts write `module-1` while the in-app content used
      // `module-01`. The strings never matched, so nothing was free and every
      // user hit a paywall on the very first tap.
      expect(SubscriptionService.isFreePreviewModule('module-1'), isTrue);
      expect(SubscriptionService.isFreePreviewModule('module-01'), isTrue);
      expect(SubscriptionService.isFreePreviewModule('module-001'), isTrue);
    });

    test('does not free any later module', () {
      expect(SubscriptionService.isFreePreviewModule('module-2'), isFalse);
      expect(SubscriptionService.isFreePreviewModule('module-02'), isFalse);
      expect(SubscriptionService.isFreePreviewModule('module-10'), isFalse);
      expect(SubscriptionService.isFreePreviewModule('module-11'), isFalse);
    });

    test('canAccessModule frees module 1 even with no entitlement', () async {
      expect(
        await SubscriptionService.canAccessModule(
          courseId: 'net-pro',
          moduleId: 'module-1',
        ),
        isTrue,
      );
    });

    test('canAccessModule gates a later module on the course', () async {
      expect(
        await SubscriptionService.canAccessModule(
          courseId: 'net-pro',
          moduleId: 'module-3',
        ),
        isFalse,
      );

      await seed({'subscriptionPlan': 'all'});
      expect(
        await SubscriptionService.canAccessModule(
          courseId: 'net-pro',
          moduleId: 'module-3',
        ),
        isTrue,
      );
    });
  });

  group('planStream', () {
    test('maps each stored plan string to its enum', () async {
      final stream = SubscriptionService.planStream();
      final seen = <SubscriptionPlan>[];
      final sub = stream.listen(seen.add);

      await seed({'subscriptionPlan': 'single'});
      await seed({'subscriptionPlan': 'bundle4'});
      await seed({'subscriptionPlan': 'all'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(seen, contains(SubscriptionPlan.single));
      expect(seen, contains(SubscriptionPlan.bundle4));
      expect(seen, contains(SubscriptionPlan.all));
    });

    test('an unknown plan string reads as none', () async {
      await seed({'subscriptionPlan': 'nonsense'});
      final plan = await SubscriptionService.planStream().first;
      expect(plan, SubscriptionPlan.none);
    });
  });

  group('trial state', () {
    test('hasUsedTrial is false before a trial and true after', () async {
      expect(await SubscriptionService.hasUsedTrial(), isFalse);
      await seed({'hasUsedTrial': true});
      expect(await SubscriptionService.hasUsedTrial(), isTrue);
    });

    test('isInActiveTrial tracks the expiry', () async {
      expect(await SubscriptionService.isInActiveTrial(), isFalse);

      await seed({'trialExpiry': inHours(2)});
      expect(await SubscriptionService.isInActiveTrial(), isTrue);

      await seed({'trialExpiry': inHours(-2)});
      expect(await SubscriptionService.isInActiveTrial(), isFalse);
    });
  });

  group('planGrantsAccess — the decision both branches share', () {
    // canAccessCourse checks the plan properly on the Firestore path, then
    // throws all of it away on the RevenueCat fallback path, which ended with:
    //
    //     return (retry...['subscriptionPlan'] ?? 'none') != 'none';
    //
    // Any plan that was not 'none' unlocked whatever course had been asked
    // for. Buy one single course, hit the reinstall path, get the catalogue.
    // That branch cannot be reached from a test (see the SCOPE NOTE above),
    // which is exactly why the decision now lives in one pure function that
    // both branches call.
    test('the all plan unlocks any course', () {
      final data = <String, dynamic>{'subscriptionPlan': 'all'};
      expect(SubscriptionService.planGrantsAccess(data, 'csm'), isTrue);
      expect(SubscriptionService.planGrantsAccess(data, 'itil-v4'), isTrue);
    });

    test('a single purchase unlocks only the course that was bought', () {
      final data = <String, dynamic>{
        'subscriptionPlan': 'single',
        'subscribedCourseId': 'csm',
      };
      expect(SubscriptionService.planGrantsAccess(data, 'csm'), isTrue);
      expect(SubscriptionService.planGrantsAccess(data, 'itil-v4'), isFalse,
          reason: 'this is the bypass: one purchase must not unlock another course');
    });

    test('a single purchase with no recorded course unlocks nothing', () {
      // setPendingPurchase can fail and be swallowed, leaving a plan with no
      // course attached. That must deny, not grant.
      final data = <String, dynamic>{'subscriptionPlan': 'single'};
      expect(SubscriptionService.planGrantsAccess(data, 'csm'), isFalse);
    });

    test('a bundle unlocks only the four courses it names', () {
      final data = <String, dynamic>{
        'subscriptionPlan': 'bundle4',
        'bundleCourseIds': ['csm', 'itil-v4', 'binary-cloud-fundamentals',
                            'binary-network-professional'],
      };
      expect(SubscriptionService.planGrantsAccess(data, 'itil-v4'), isTrue);
      expect(
          SubscriptionService.planGrantsAccess(
              data, 'binary-cybersecurity-professional'),
          isFalse);
    });

    test('a bundle with no course list unlocks nothing', () {
      final data = <String, dynamic>{'subscriptionPlan': 'bundle4'};
      expect(SubscriptionService.planGrantsAccess(data, 'csm'), isFalse);
    });

    test('no plan grants nothing', () {
      expect(SubscriptionService.planGrantsAccess(<String, dynamic>{}, 'csm'),
          isFalse);
      expect(
          SubscriptionService.planGrantsAccess(
              <String, dynamic>{'subscriptionPlan': 'none'}, 'csm'),
          isFalse);
    });

    test('an unrecognised plan name grants nothing', () {
      // A future plan the server knows about and this build does not must fail
      // closed, never open.
      expect(
          SubscriptionService.planGrantsAccess(
              <String, dynamic>{'subscriptionPlan': 'lifetime-pro'}, 'csm'),
          isFalse);
    });
  });
}
