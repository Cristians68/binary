import 'package:binary/screens/auth_service.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class _User extends Fake implements User {
  _User(this.uid, {this.isAnonymous = false});
  @override
  final String uid;
  @override
  bool isAnonymous;
  @override
  String? displayName;
  FirebaseAuthException? linkError;
  FirebaseAuthException? reauthError;
  AuthCredential? linked;
  AuthCredential? reauthenticated;
  int providerReauthCalls = 0;

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    linked = credential;
    if (linkError != null) throw linkError!;
    isAnonymous = false;
    return _Credential(this);
  }

  @override
  Future<void> updateDisplayName(String? value) async => displayName = value;

  @override
  Future<UserCredential> reauthenticateWithCredential(
      AuthCredential credential) async {
    reauthenticated = credential;
    if (reauthError != null) throw reauthError!;
    return _Credential(this);
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(
      AuthProvider provider) async {
    providerReauthCalls++;
    throw StateError('The scene-unsafe presenter must not be used on iOS');
  }
}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);
  @override
  final User user;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  final credentials = <AuthCredential>[];
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentials.add(credential);
    currentUser = _User('member');
    return _Credential(currentUser!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.binaryapp/apple-auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Auth auth;
  late FakeFirebaseFirestore db;
  late List<String> nonces;
  String? secondError;
  String secondUser = 'apple-user';

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    auth = _Auth();
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db);
    ServiceBackend.useAuth(auth);
    nonces = [];
    secondError = null;
    secondUser = 'apple-user';
    messenger.setMockMethodCallHandler(channel, (call) async {
      nonces.add(call.arguments['nonce'] as String);
      if (nonces.length == 2 && secondError != null) {
        throw PlatformException(code: secondError!);
      }
      return {
        'identityToken': 'token-${nonces.length}',
        'authorizationCode': 'code-${nonces.length}',
        'userIdentifier': nonces.length == 1 ? 'apple-user' : secondUser,
        if (nonces.length == 1) 'givenName': 'Ada',
        if (nonces.length == 1) 'familyName': 'Lovelace',
      };
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    ServiceBackend.reset();
  });

  test('native sign-in uses the Apple credential, matching nonce and name',
      () async {
    expect((await AuthService.signInWithApple()).isSuccess, isTrue);
    final credential = auth.credentials.single as OAuthCredential;
    expect(credential.signInMethod, 'apple.com');
    expect(credential.idToken, 'token-1');
    expect(sha256.convert(utf8.encode(credential.rawNonce!)).toString(),
        nonces.single);
    expect(credential.appleFullPersonName?.givenName, 'Ada');
    expect(credential.appleFullPersonName?.familyName, 'Lovelace');
    expect(credential.accessToken, isNull);
    expect(
        (await db.doc('users/member').get()).data()?['name'], 'Ada Lovelace');
  });

  test('guest upgrade preserves the uid and existing study history', () async {
    final guest = _User('guest', isAnonymous: true);
    auth.currentUser = guest;
    await db
        .doc('users/guest')
        .set({'createdAt': DateTime(2026), 'quizzesPassed': 4});
    expect((await AuthService.signInWithApple()).isSuccess, isTrue);
    expect(auth.currentUser?.uid, 'guest');
    expect(guest.isAnonymous, isFalse);
    expect(auth.credentials, isEmpty);
    expect((await db.doc('users/guest').get()).data()?['quizzesPassed'], 4);
  });

  test(
      'an existing account uses the returned replacement without another sheet',
      () async {
    final replacement =
        OAuthProvider('apple.com').credential(idToken: 'replacement');
    auth.currentUser = _User('guest', isAnonymous: true)
      ..linkError = FirebaseAuthException(
          code: 'credential-already-in-use', credential: replacement);
    expect((await AuthService.signInWithApple()).isSuccess, isTrue);
    expect(auth.credentials.single, same(replacement));
    expect(nonces, hasLength(1));
  });

  test(
      'missing replacement obtains a new token instead of replaying a used one',
      () async {
    auth.currentUser = _User('guest', isAnonymous: true)
      ..linkError = FirebaseAuthException(code: 'credential-already-in-use');
    expect((await AuthService.signInWithApple()).isSuccess, isTrue);
    final credential = auth.credentials.single as OAuthCredential;
    expect(credential.idToken, 'token-2');
    expect(nonces, hasLength(2));
    expect(nonces[0], isNot(nonces[1]));
    expect(sha256.convert(utf8.encode(credential.rawNonce!)).toString(),
        nonces[1]);
  });

  test('cancelling renewed authorization leaves the guest signed in', () async {
    auth.currentUser = _User('guest', isAnonymous: true)
      ..linkError = FirebaseAuthException(code: 'credential-already-in-use');
    secondError = 'canceled';
    expect((await AuthService.signInWithApple()).isCancelled, isTrue);
    expect(auth.currentUser?.uid, 'guest');
    expect(auth.credentials, isEmpty);
  });

  test('renewed authorization cannot silently switch Apple accounts', () async {
    auth.currentUser = _User('guest', isAnonymous: true)
      ..linkError = FirebaseAuthException(code: 'credential-already-in-use');
    secondUser = 'another-apple-user';
    expect((await AuthService.signInWithApple()).code, 'user-mismatch');
    expect(auth.currentUser?.uid, 'guest');
    expect(auth.credentials, isEmpty);
  });

  test('Apple deletion reauth uses the Apple credential and returns its code',
      () async {
    final user = _User('member');
    auth.currentUser = user;
    final result = await AuthService.reauthenticateWithApple();
    expect(result.result.isSuccess, isTrue);
    expect(result.authorizationCode, 'code-1');
    expect(user.reauthenticated?.signInMethod, 'apple.com');
    expect(user.providerReauthCalls, 0);
  });

  test('a failed iOS reauth never invokes the unsafe provider presenter',
      () async {
    final user = _User('member')
      ..reauthError = FirebaseAuthException(code: 'invalid-credential');
    auth.currentUser = user;
    final result = await AuthService.reauthenticateWithApple();
    expect(result.result.code, 'invalid-credential');
    expect(result.authorizationCode, isNull);
    expect(user.providerReauthCalls, 0);
    expect(auth.currentUser, same(user));
  });
}
