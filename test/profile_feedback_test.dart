import 'dart:async';

import 'package:binary/screens/app_theme.dart';
import 'package:binary/screens/feedback_sheet.dart';
import 'package:binary/screens/profile_screen.dart';
import 'package:binary/screens/profile_avatar.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User extends Fake implements User {
  _User(this.displayName);
  @override
  final String? displayName;
  @override
  String get uid => 'learner';
  @override
  String? get email => null;
  @override
  String? get photoURL => null;
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [];
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(String? name) : currentUser = _User(name);
  @override
  final User currentUser;
}

// Intentional test double: only add() is exercised, with a controlled completion.
// ignore: subtype_of_sealed_class
class _PendingCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final result = Completer<DocumentReference<Map<String, dynamic>>>();
  final _writes = <Map<String, dynamic>>[];
  int get writes => _writes.length;
  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
      Map<String, dynamic> data) {
    _writes.add(data);
    return result.future;
  }
}

class _PendingDb extends Fake implements FirebaseFirestore {
  final feedback = _PendingCollection();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'feedback');
    return feedback;
  }
}

void main() {
  late FakeFirebaseFirestore db;
  final reviewCalls = <MethodCall>[];
  const reviewChannel = MethodChannel('dev.britannio.in_app_review');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'learner');
    reviewCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(reviewChannel, (call) async {
      reviewCalls.add(call);
      return true;
    });
  });
  tearDown(() {
    ServiceBackend.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(reviewChannel, null);
  });

  Future<void> pump(WidgetTester tester, Widget child,
      {Size size = const Size(390, 844), double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => AppTheme(
        notifier: ThemeNotifier(),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: const EdgeInsets.only(bottom: 200)),
          child: child!,
        ),
      ),
      home: Scaffold(body: child),
    ));
    await tester.pumpAndSettle();
  }

  Finder getSend() => find.widgetWithText(FilledButton, 'Send feedback');
  Future<void> send(WidgetTester tester) async {
    // Let the keyboard's viewport change settle before calculating scrolling.
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(getSend()), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(getSend().hitTestable(), findsOneWidget);
    await tester.tap(getSend());
    await tester.pumpAndSettle();
  }

  for (final entry in {
    '  Alex   Learner  ': 'AL',
    '\t\n': 'U',
    '👩🏽‍💻 Developer': '👩🏽‍💻D',
    '單': '單',
  }.entries) {
    testWidgets('Profile handles name ${entry.key}', (tester) async {
      ServiceBackend.useAuth(_Auth(entry.key));
      await pump(tester, const ProfileScreen());
      expect(
          find.descendant(
              of: find.byType(ProfileAvatar), matching: find.text(entry.value)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final stars in [1, 5]) {
    testWidgets('$stars-star feedback saves without triggering a store review',
        (tester) async {
      await pump(tester, const FeedbackSheet());
      await tester
          .tap(find.byTooltip('$stars ${stars == 1 ? 'star' : 'stars'}'));
      await tester.enterText(find.byType(TextField), '  Keep my feedback.  ');
      await send(tester);
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
      final docs = (await db.collection('feedback').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data(), containsPair('uid', 'learner'));
      expect(docs.single.data(), containsPair('stars', stars));
      expect(docs.single.data(), containsPair('message', 'Keep my feedback.'));
      expect(docs.single.data()['appVersion'], isNot('1.0.0'));
      expect(reviewCalls, isEmpty);
    });
  }

  testWidgets('failed send retains the draft and permits a successful retry',
      (tester) async {
    final denied = FakeFirebaseFirestore(securityRules: '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} { allow read, write: if false; }
  }
}''');
    ServiceBackend.useFake(denied, uid: 'learner');
    await pump(tester, const FeedbackSheet());
    await tester.enterText(find.byType(TextField), 'Do not lose this draft.');
    await send(tester);
    expect(find.text('Thanks for your feedback!'), findsNothing);
    expect(find.textContaining('Feedback could not be sent.'), findsOneWidget);
    expect(find.text('Do not lose this draft.'), findsOneWidget);
    ServiceBackend.useFake(db, uid: 'learner');
    await send(tester);
    expect(find.text('Thanks for your feedback!'), findsOneWidget);
    expect((await db.collection('feedback').get()).docs, hasLength(1));
  });

  testWidgets('empty and signed-out feedback never writes', (tester) async {
    await pump(tester, const FeedbackSheet());
    await send(tester);
    expect(find.text('Please add a rating or message.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'My message');
    ServiceBackend.useFake(db, uid: null);
    await send(tester);
    expect(find.text('Sign in again to send feedback.'), findsOneWidget);
    expect((await db.collection('feedback').get()).docs, isEmpty);
  });

  testWidgets('pending sends resist double taps and safe disposal',
      (tester) async {
    final pending = _PendingDb();
    ServiceBackend.useFake(pending, uid: 'learner');
    await pump(tester, const FeedbackSheet());
    await tester.enterText(find.byType(TextField), 'Pending feedback');
    await tester.ensureVisible(getSend());
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(getSend());
    button.onPressed!();
    button.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(pending.feedback.writes, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
    pending.feedback.result.completeError(StateError('Connection failed'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'feedback stays usable with a keyboard, short window and large text',
      (tester) async {
    await pump(tester, const FeedbackSheet(),
        size: const Size(320, 320), scale: 2);
    await tester.enterText(find.byType(TextField), 'Small screen feedback');
    await send(tester);
    await tester.ensureVisible(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Done').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
