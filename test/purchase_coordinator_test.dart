import 'package:binary/screens/purchase_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String? uid;
  late Map<String, dynamic> account;
  late Map<String, dynamic> state;
  late List<String> calls;
  late PurchaseCoordinator coordinator;
  bool alreadyOwned = false;
  Object? preflightError;
  Object? refreshError;
  Future<void> Function()? duringBuy;
  Future<void> Function()? duringRefresh;
  Future<void> Function()? duringRead;
  Future<void> Function()? duringPause;
  final single =
      PurchaseRequest(productId: 'binary_course_itsm', courseId: 'itil-v4');

  setUp(() {
    uid = 'buyer';
    account = {};
    state = {
      'activeProductIds': [],
      'purchasedCourseIds': [],
      'unresolvedProductIds': []
    };
    calls = [];
    alreadyOwned = false;
    preflightError = null;
    refreshError = null;
    duringBuy = null;
    duringRefresh = null;
    duringRead = null;
    duringPause = null;
    coordinator = PurchaseCoordinator(
      currentUid: () => uid,
      identify: (id) async {
        calls.add('identify:$id');
      },
      prepare: (request) async {
        calls.add('prepare');
        if (preflightError != null) throw preflightError!;
        return alreadyOwned;
      },
      refresh: () async {
        calls.add('refresh');
        await duringRefresh?.call();
        if (refreshError != null) throw refreshError!;
        return state;
      },
      readAccount: (id) async {
        calls.add('read:$id');
        await duringRead?.call();
        return account;
      },
      pause: () async {
        await duringPause?.call();
      },
      attempts: 2,
    );
  });
  Future<void> buy() async {
    calls.add('buy');
    await duringBuy?.call();
  }

  test('unavailable preflight never opens the store payment sheet', () async {
    preflightError = StateError('functions not deployed');
    await expectLater(
        coordinator.purchase(single, buy),
        throwsA(isA<PurchaseFailure>().having(
            (e) => e.message, 'message', contains('No payment was started'))));
    expect(calls, ['identify:buyer', 'prepare']);
  });

  test('signed-out users never reach RevenueCat or the payment sheet',
      () async {
    uid = null;
    await expectLater(
        coordinator.purchase(single, buy), throwsA(isA<PurchaseFailure>()));
    expect(calls, isEmpty);
  });

  test(
      'an existing purchase skips payment only if the chosen course is accessible',
      () async {
    alreadyOwned = true;
    account = {
      'subscriptionPlan': 'single',
      'purchasedCourseIds': ['itil-v4']
    };
    expect(await coordinator.purchase(single, buy), isTrue);
    expect(calls, isNot(contains('buy')));
    account = {'subscriptionPlan': 'single', 'subscribedCourseId': 'csm'};
    await expectLater(
        coordinator.purchase(single, buy), throwsA(isA<PurchaseFailure>()));
    expect(calls, isNot(contains('buy')));
  });

  test(
      'a preexisting different course cannot turn a new payment into false success',
      () async {
    account = {'subscriptionPlan': 'single', 'subscribedCourseId': 'csm'};
    await expectLater(
        coordinator.purchase(single, buy),
        throwsA(isA<PurchaseFailure>().having(
            (e) => e.message, 'message', startsWith('Payment received'))));
    expect(calls.where((c) => c == 'buy').length, 1);
  });

  test('bundle activation requires all four selected courses', () async {
    const four = [
      'itil-v4',
      'csm',
      'binary-network-professional',
      'binary-cloud-fundamentals'
    ];
    final bundle =
        PurchaseRequest(productId: kProductBundle4, selectedCourseIds: four);
    account = {
      'subscriptionPlan': 'bundle4',
      'purchasedCourseIds': four.take(3).toList()
    };
    await expectLater(
        coordinator.purchase(bundle, buy), throwsA(isA<PurchaseFailure>()));
    account['purchasedCourseIds'] = four;
    expect(await coordinator.purchase(bundle, buy), isTrue);
  });

  test(
      'server activation makes a second individual purchase usable without losing the first',
      () async {
    account = {
      'subscriptionPlan': 'single',
      'purchasedCourseIds': ['csm', 'itil-v4']
    };
    expect(await coordinator.purchase(single, buy), isTrue);
    expect(paidCourseAccess(account, 'csm'), isTrue);
    expect(paidCourseAccess(account, 'binary-cloud-fundamentals'), isFalse);
  });

  test(
      'a successful webhook can finish activation while the callable is temporarily unavailable',
      () async {
    refreshError = StateError('offline');
    account = {
      'subscriptionPlan': 'single',
      'purchasedCourseIds': ['itil-v4']
    };
    expect(await coordinator.purchase(single, buy), isTrue);
  });

  test('a store cancellation does not start activation or retry payment',
      () async {
    duringBuy = () async {
      throw StateError('cancelled');
    };
    await expectLater(coordinator.purchase(single, buy), throwsStateError);
    expect(calls, ['identify:buyer', 'prepare', 'buy']);
  });

  test(
      'changing account during payment cannot activate or read the other account',
      () async {
    duringBuy = () async {
      uid = 'someone-else';
    };
    account = {'subscriptionPlan': 'all'};
    await expectLater(
        coordinator.purchase(single, buy),
        throwsA(isA<PurchaseFailure>()
            .having((e) => e.message, 'message', contains('account changed'))));
    expect(calls, isNot(contains('refresh')));
    expect(calls, isNot(contains('read:someone-else')));
  });

  test(
      'restore distinguishes an empty verified inventory from a server failure',
      () async {
    expect((await coordinator.restore(() async => false)).foundNothing, isTrue);
    refreshError = StateError('API unavailable');
    expect((await coordinator.restore(() async => false)).isFailure, isTrue);
    expect((await coordinator.restore(() async => true)).isPending, isTrue);
  });

  test(
      'unresolved legacy course choices stay pending even if another course is usable',
      () async {
    state = {
      'activeProductIds': [kProductSingle, 'binary_course_itsm'],
      'unresolvedProductIds': [kProductSingle],
      'purchasedCourseIds': ['itil-v4']
    };
    account = {
      'subscriptionPlan': 'single',
      'purchasedCourseIds': ['itil-v4']
    };
    expect((await coordinator.restore(() async => true)).isPending, isTrue);
  });

  test('a store purchase with delayed server inventory never reports nothing',
      () async {
    final result = await coordinator.restore(() async => true);
    expect(result.isPending, isTrue);
    expect(result.foundNothing, isFalse);
    expect(calls.where((call) => call == 'refresh'), hasLength(2));
  });

  for (final boundary in ['refresh', 'read']) {
    test(
        'restore retries a transient $boundary failure without restoring twice',
        () async {
      state = {
        'subscriptionPlan': 'single',
        'activeProductIds': ['binary_course_itsm'],
        'purchasedCourseIds': ['itil-v4'],
        'unresolvedProductIds': [],
      };
      account = {
        'subscriptionPlan': 'single',
        'purchasedCourseIds': ['itil-v4'],
      };
      var failures = 0;
      Future<void> failOnce() async {
        if (failures++ == 0) throw StateError('temporary network failure');
      }

      if (boundary == 'refresh') {
        duringRefresh = failOnce;
      } else {
        duringRead = failOnce;
      }
      var restores = 0;
      final result = await coordinator.restore(() async {
        restores++;
        return true;
      });
      expect(result.isApplied, isTrue);
      expect(restores, 1);
      expect(calls.where((call) => call == 'refresh'), hasLength(2));
    });
  }

  test('account change between restore retries stops the next server call',
      () async {
    duringPause = () async {
      uid = 'someone-else';
    };
    final result = await coordinator.restore(() async => true);
    expect(result.isFailure, isTrue);
    expect(result.message, contains('account changed'));
    expect(calls.where((call) => call == 'refresh'), hasLength(1));
  });

  test('a malformed restore response cannot claim all purchases were restored',
      () async {
    state = {
      'subscriptionPlan': 'all',
      'activeProductIds': [kProductBundleAll],
      // Missing unresolvedProductIds must not look like an empty list.
      'purchasedCourseIds': [],
    };
    account = {'subscriptionPlan': 'all'};
    expect((await coordinator.restore(() async => true)).isApplied, isFalse);
  });

  test('restore reports success only after every verified course is readable',
      () async {
    state = {
      'activeProductIds': ['binary_course_itsm', 'binary_course_scrm'],
      'purchasedCourseIds': ['itil-v4', 'csm'],
      'unresolvedProductIds': []
    };
    account = {
      'subscriptionPlan': 'single',
      'purchasedCourseIds': ['itil-v4']
    };
    expect((await coordinator.restore(() async => true)).isPending, isTrue);
    account['purchasedCourseIds'] = ['itil-v4', 'csm'];
    expect((await coordinator.restore(() async => true)).isApplied, isTrue);
  });

  test('unknown plans cannot activate a purchase through a stray course list',
      () {
    expect(
        single.isApplied({
          'subscriptionPlan': 'unknown',
          'purchasedCourseIds': ['itil-v4']
        }),
        isFalse);
  });

  test(
      'mismatched and legacy single-course packages cannot start a new checkout',
      () {
    expect(
        () => PurchaseRequest(productId: kProductSingle, courseId: 'itil-v4'),
        throwsA(isA<PurchaseFailure>()));
    expect(
        () => PurchaseRequest(
            productId: 'binary_course_scrm', courseId: 'itil-v4'),
        throwsA(isA<PurchaseFailure>()));
  });
}
