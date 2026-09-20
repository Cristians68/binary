import 'dart:async';

import 'package:binary/screens/service_backend.dart';
import 'package:binary/screens/streak_service.dart';
import 'package:binary/screens/user_streams.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits for native listener cancellation before revoking credentials',
      () async {
    final scope = UserStreams();
    final cancelled = Completer<void>();
    final source = StreamController<int>(onCancel: () => cancelled.future);
    final subscription = scope.bind(source.stream).listen((_) {});
    var signedOut = false;
    final signOut = scope.transition(() async => signedOut = true);
    await Future<void>.delayed(Duration.zero);
    expect(signedOut, isFalse);
    cancelled.complete();
    await signOut;
    expect(signedOut, isTrue);
    expect(source.hasListener, isFalse);
    await subscription.cancel();
    await source.close();
  });

  test('includes cancellations already started by widget disposal', () async {
    final scope = UserStreams();
    final cancelled = Completer<void>();
    final source = StreamController<int>(onCancel: () => cancelled.future);
    final subscription = scope.bind(source.stream).listen((_) {});
    final disposing = subscription.cancel();
    var signedOut = false;
    final signOut = scope.transition(() async => signedOut = true);
    await Future<void>.delayed(Duration.zero);
    expect(signedOut, isFalse);
    cancelled.complete();
    await Future.wait([disposing, signOut]);
    expect(signedOut, isTrue);
    await source.close();
  });

  test('paused UI consumers do not block sign-out', () async {
    final scope = UserStreams();
    final source = StreamController<int>();
    final subscription = scope.bind(source.stream).listen((_) {})..pause();
    await scope.transition(() async {}).timeout(const Duration(seconds: 1));
    expect(source.hasListener, isFalse);
    await subscription.cancel();
    await source.close();
  });

  test('stale and mid-sign-out streams cannot attach to the old account',
      () async {
    final scope = UserStreams();
    final source = StreamController<int>.broadcast();
    final stale = scope.bind(source.stream);
    final finishSignOut = Completer<void>();
    final signOut = scope.transition(() => finishSignOut.future);
    final during = scope.bind(source.stream);
    finishSignOut.complete();
    await signOut;
    expect(await stale.toList(), isEmpty);
    expect(await during.toList(), isEmpty);
    expect(source.hasListener, isFalse);
    final nextSession = scope.bind(source.stream).listen((_) {});
    expect(source.hasListener, isTrue);
    await nextSession.cancel();
    await source.close();
  });

  test('normal data and errors are forwarded to the screen handler', () async {
    final scope = UserStreams();
    final source = StreamController<int>();
    final events = <Object>[];
    final subscription = scope
        .bind(source.stream)
        .listen(events.add, onError: (Object error) => events.add(error));
    source.add(3);
    source.addError(StateError('permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(events.first, 3);
    expect(events.last, isA<StateError>());
    await subscription.cancel();
    await source.close();
  });

  test('a failed auth change releases the gate for retry', () async {
    final scope = UserStreams();
    await expectLater(scope.transition(() async => throw StateError('offline')),
        throwsStateError);
    expect(await scope.bind(Stream.value(7)).single, 7);
    expect(await scope.transition(() async => 'signed out'), 'signed out');
  });

  test(
      'stats and progress detach before sign-out and the next account can listen',
      () async {
    final db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'first');
    addTearDown(ServiceBackend.reset);
    await db.doc('users/first').set({'name': 'First'});
    final events = <Object>[];
    final stats = StreakService.statsStream().listen(events.add);
    final progress = ServiceBackend.watchProgress().listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(2));

    await ServiceBackend.userStreams.transition(() async {
      ServiceBackend.useFake(db);
      await db.doc('users/first').update({'name': 'Old account changed'});
      await db.doc('users/first/progress/course').set({'progress': 1.0});
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(2));
    expect(await ServiceBackend.watchUser().toList(), isEmpty);

    ServiceBackend.useFake(db, uid: 'second');
    await db.doc('users/second').set({'name': 'Second'});
    expect((await StreakService.statsStream().first)['name'], 'Second');
    await stats.cancel();
    await progress.cancel();
  });
}
