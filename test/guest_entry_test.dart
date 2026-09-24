import 'package:binary/main.dart';
import 'package:binary/screens/auth_service.dart';
import 'package:binary/screens/login_screen.dart';
import 'package:binary/screens/main_navigation.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:binary/screens/welcome_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User extends Fake implements User {
  _User(this.uid, {this.isAnonymous = true});

  @override
  final String uid;
  @override
  final bool isAnonymous;
  @override
  String? get displayName => null;
}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);

  @override
  final User user;
}

class _Auth extends Fake implements FirebaseAuth {
  User? user;
  int anonymousCalls = 0;
  int signOutCalls = 0;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> signInAnonymously() async {
    anonymousCalls++;
    user = _User('new-guest');
    return _Credential(user!);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    user = null;
  }
}

class _CancelledGoogle extends GoogleSignInPlatform {
  int attempts = 0;

  @override
  Future<void> init(InitParameters params) async {}
  @override
  bool supportsAuthenticate() => true;
  @override
  Future<void> signOut(SignOutParams params) async {}
  @override
  Future<AuthenticationResults> authenticate(
      AuthenticateParameters params) async {
    attempts++;
    throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late FakeFirebaseFirestore db;

  setUp(() {
    SharedPreferences.setMockInitialValues({kOnboardingCompleteKey: true});
    GoogleFonts.config.allowRuntimeFetching = false;
    auth = _Auth()..user = _User('saved-guest');
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'saved-guest');
    ServiceBackend.useAuth(auth);
  });
  tearDown(ServiceBackend.reset);

  testWidgets('restored guest can choose Google without signing out',
      (tester) async {
    final original = GoogleSignInPlatform.instance;
    final google = _CancelledGoogle();
    GoogleSignInPlatform.instance = google;
    addTearDown(() => GoogleSignInPlatform.instance = original);
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BinaryApp(initialIsDark: false));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
    expect(auth.currentUser?.uid, 'saved-guest');
    expect(auth.anonymousCalls, 0);

    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(google.attempts, 1);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(auth.signOutCalls, 0);
    expect(auth.currentUser?.uid, 'saved-guest');
    expect(find.textContaining('sign-in failed'), findsNothing);
  });

  test('Continue as guest preserves the restored identity and progress',
      () async {
    await db.doc('users/saved-guest').set({
      'createdAt': DateTime(2026),
      'quizzesPassed': 9,
      'enrolments': {'course': true},
    });
    expect((await AuthService.signInAsGuest()).isSuccess, isTrue);
    expect(auth.currentUser?.uid, 'saved-guest');
    expect(auth.anonymousCalls, 0);
    expect(
        (await db.doc('users/saved-guest').get()).data()?['quizzesPassed'], 9);
  });

  test('an explicit guest choice creates an identity only when signed out',
      () async {
    auth.user = null;
    expect((await AuthService.signInAsGuest()).isSuccess, isTrue);
    expect(auth.anonymousCalls, 1);
    expect(auth.currentUser?.uid, 'new-guest');
    expect((await db.doc('users/new-guest').get()).exists, isTrue);
  });

  test('a stale guest action cannot replace a registered account', () async {
    auth.user = _User('member', isAnonymous: false);
    expect((await AuthService.signInAsGuest()).isSuccess, isTrue);
    expect(auth.currentUser?.uid, 'member');
    expect(auth.anonymousCalls, 0);
    expect((await db.doc('users/new-guest').get()).exists, isFalse);
  });

  // Every other forward push swipes back from the left edge like any iOS
  // app; Welcome's Log in and Create an account used a plain
  // PageRouteBuilder, which has no back gesture at all.
  testWidgets('Log in can be swiped back to Welcome from the left edge',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BinaryApp(initialIsDark: false));
    await tester.pumpAndSettle();
    final logIn = find.text('Already learning with us? Log in');
    await tester.ensureVisible(logIn);
    await tester.tap(logIn);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(3, 500));
    for (var moved = 0.0; moved < 400; moved += 40) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
