# Profile Photo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a learner set a private profile photo, stored free in Firestore, shown on Profile and the Home sheet, falling back to their Google photo and then initials.

**Architecture:** `image_picker` downsizes natively to ≤256px JPEG. `ProfilePhotoService` stores the bytes as a Firestore `Blob` at `users/{uid}/profile/photo`, with its listener bound through `ServiceBackend.userStreams` so sign-out cancels it like every other account listener. A `ProfileAvatar` widget applies the precedence rule custom → provider URL → initials.

**Tech Stack:** Flutter 3.47.2, cloud_firestore 5.6.12, image_picker 1.2.3, fake_cloud_firestore (tests), Firestore rules, Node `node --test` for functions.

Spec: `docs/superpowers/specs/2026-09-23-profile-photo-design.md`

## Global Constraints

- Firestore path: `users/{uid}/profile/photo`, fields exactly `jpeg` (bytes) and `updatedAt` (server timestamp).
- Size cap: `150 * 1024` bytes, enforced client-side AND in rules.
- Picker: `ImageSource.gallery`, `maxWidth: 256`, `maxHeight: 256`, `imageQuality: 80`, `requestFullMetadata: false`. No camera, no cropping.
- Precedence: custom photo → `FirebaseAuth.currentUser.photoURL` → initials.
- Every account listener goes through `ServiceBackend.userStreams.bind` (sign-out crash fix depends on it).
- Info.plist must carry non-empty `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription`.
- `flutter analyze` must stay at zero, including with `tools/screenshots/fixture_content.dart` moved aside (CI conditions).
- Rules deploy is a production change: the USER runs `firebase deploy --only firestore:rules`.

---

### Task 1: Dependency and iOS purpose strings

**Files:**
- Modify: `pubspec.yaml` (add `image_picker: ^1.2.3`)
- Modify: `ios/Runner/Info.plist` (after `NSUserNotificationUsageDescription`)
- Test: `test/ios_native_crash_guards_test.dart`

- [ ] **Step 1: Write the failing test** — append inside `main()`:

```dart
  test('Info.plist explains every protected API the photo picker links', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in ['NSPhotoLibraryUsageDescription', 'NSCameraUsageDescription']) {
      final value = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
          .firstMatch(plist)
          ?.group(1);
      expect(value?.trim(), isNotEmpty,
          reason: '$key missing: App Store upload is rejected (ITMS-90683) and '
              'a permission request without it terminates the app');
    }
  });
```

- [ ] **Step 2: Run** `flutter test test/ios_native_crash_guards_test.dart` — Expected: FAIL on `NSPhotoLibraryUsageDescription`.
- [ ] **Step 3: Implement** — `flutter pub add image_picker:^1.2.3`, then in Info.plist after the notification string:

```xml
	<key>NSPhotoLibraryUsageDescription</key>
	<string>B1nary uses a photo you choose as your profile picture.</string>
	<key>NSCameraUsageDescription</key>
	<string>B1nary can use the camera for your profile picture.</string>
```

- [ ] **Step 4: Run** the same test — Expected: PASS.
- [ ] **Step 5: Commit** `pubspec.yaml pubspec.lock ios/Runner/Info.plist test/ios_native_crash_guards_test.dart`.

### Task 2: Pure rules and ProfilePhotoService

**Files:**
- Create: `lib/screens/profile_photo.dart`
- Test: `test/profile_photo_test.dart`

**Interfaces — Produces:**
- `enum AvatarSource { custom, provider, initials }`
- `AvatarSource avatarSourceFor({Uint8List? custom, String? photoUrl})`
- `const int kMaxProfilePhotoBytes = 150 * 1024;`
- `bool isAcceptablePhoto(Uint8List bytes)` — non-empty and ≤ cap
- `class ProfilePhotoService { static Stream<Uint8List?> watch(); static Future<void> save(Uint8List bytes); static Future<void> remove(); }` — `save` throws `ArgumentError` for unacceptable bytes.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:typed_data';

import 'package:binary/screens/profile_photo.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatarSourceFor', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    test('a custom photo beats the provider photo', () {
      expect(avatarSourceFor(custom: bytes, photoUrl: 'https://x/p.jpg'),
          AvatarSource.custom);
    });
    test('the provider photo beats initials', () {
      expect(avatarSourceFor(photoUrl: 'https://x/p.jpg'), AvatarSource.provider);
    });
    test('initials when there is neither', () {
      expect(avatarSourceFor(), AvatarSource.initials);
      expect(avatarSourceFor(custom: Uint8List(0), photoUrl: ''),
          AvatarSource.initials);
    });
  });

  group('isAcceptablePhoto', () {
    test('accepts exactly the cap and rejects one byte more', () {
      expect(isAcceptablePhoto(Uint8List(kMaxProfilePhotoBytes)), isTrue);
      expect(isAcceptablePhoto(Uint8List(kMaxProfilePhotoBytes + 1)), isFalse);
    });
    test('rejects empty bytes', () {
      expect(isAcceptablePhoto(Uint8List(0)), isFalse);
    });
  });

  group('ProfilePhotoService', () {
    late FakeFirebaseFirestore db;
    setUp(() {
      db = FakeFirebaseFirestore();
      ServiceBackend.useFake(db, uid: 'learner-1');
    });
    tearDown(ServiceBackend.reset);

    test('save writes only jpeg + updatedAt under the owner', () async {
      await ProfilePhotoService.save(Uint8List.fromList([9, 8, 7]));
      final doc = await db.doc('users/learner-1/profile/photo').get();
      expect(doc.data()!.keys.toSet(), {'jpeg', 'updatedAt'});
      expect((doc.data()!['jpeg'] as Blob).bytes, [9, 8, 7]);
    });
    test('watch delivers the saved bytes, then null after remove', () async {
      final seen = <List<int>?>[];
      final sub = ProfilePhotoService.watch().listen(seen.add);
      await ProfilePhotoService.save(Uint8List.fromList([5]));
      await pumpEventQueue();
      await ProfilePhotoService.remove();
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.last, isNull);
      expect(seen, contains(equals([5])));
    });
    test('save refuses an oversize photo without writing', () async {
      expect(() => ProfilePhotoService.save(Uint8List(kMaxProfilePhotoBytes + 1)),
          throwsArgumentError);
      final doc = await db.doc('users/learner-1/profile/photo').get();
      expect(doc.exists, isFalse);
    });
    test('watch is null with no signed-in user', () async {
      ServiceBackend.useFake(db, uid: null);
      expect(await ProfilePhotoService.watch().first, isNull);
    });
  });
}
```

- [ ] **Step 2: Run** `flutter test test/profile_photo_test.dart` — Expected: FAIL, `profile_photo.dart` does not exist.
- [ ] **Step 3: Implement** `lib/screens/profile_photo.dart`:

```dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_backend.dart';

enum AvatarSource { custom, provider, initials }

/// Custom photo, then the sign-in provider's photo (Google), then initials.
AvatarSource avatarSourceFor({Uint8List? custom, String? photoUrl}) {
  if (custom != null && custom.isNotEmpty) return AvatarSource.custom;
  if (photoUrl != null && photoUrl.isNotEmpty) return AvatarSource.provider;
  return AvatarSource.initials;
}

/// Mirrors the cap in firestore.rules. The picker downsizes to 256px, which
/// lands around 20-40 KB, so this only trips on something unexpected.
const int kMaxProfilePhotoBytes = 150 * 1024;

bool isAcceptablePhoto(Uint8List bytes) =>
    bytes.isNotEmpty && bytes.length <= kMaxProfilePhotoBytes;

/// The learner's own photo, private to them, stored free on Spark.
///
/// Kept in its own document rather than on users/{uid}: that document is
/// streamed and re-delivered on every progress write, and 30 KB riding on it
/// would multiply every one of those snapshots.
class ProfilePhotoService {
  ProfilePhotoService._();

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = ServiceBackend.uid;
    if (uid == null) return null;
    return ServiceBackend.db.doc('users/$uid/profile/photo');
  }

  static Stream<Uint8List?> watch() {
    final doc = _doc();
    if (doc == null) return Stream.value(null);
    return ServiceBackend.userStreams.bind(doc.snapshots()).map((snap) {
      final blob = snap.data()?['jpeg'];
      return blob is Blob ? blob.bytes : null;
    });
  }

  static Future<void> save(Uint8List bytes) async {
    if (!isAcceptablePhoto(bytes)) {
      throw ArgumentError('Photo must be 1..$kMaxProfilePhotoBytes bytes');
    }
    final doc = _doc();
    if (doc == null) throw StateError('No signed-in user');
    await doc.set({'jpeg': Blob(bytes), 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> remove() async => _doc()?.delete();
}
```

- [ ] **Step 4: Run** the test — Expected: PASS (all 9).
- [ ] **Step 5: Commit** `lib/screens/profile_photo.dart test/profile_photo_test.dart`.

### Task 3: ProfileAvatar widget

**Files:**
- Create: `lib/screens/profile_avatar.dart`
- Test: `test/profile_avatar_test.dart`

**Interfaces:**
- Consumes: `ProfilePhotoService.watch()`, `avatarSourceFor`, `AvatarSource`.
- Produces: `ProfileAvatar({Key? key, required double radius, required String initials, required String? photoUrl, double fontSize = 22})`. Callers pass `FirebaseAuth.instance.currentUser?.photoURL` explicitly, which keeps the widget free of Firebase singletons and testable.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:typed_data';

import 'package:binary/screens/profile_avatar.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 transparent PNG — decodable, so Image.memory paints without error.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  late FakeFirebaseFirestore db;
  setUp(() {
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'learner-1');
  });
  tearDown(ServiceBackend.reset);

  testWidgets('shows initials when there is no photo', (tester) async {
    await tester.pumpWidget(_host(const ProfileAvatar(radius: 30, initials: 'AL', photoUrl: null)));
    await tester.pump();
    expect(find.text('AL'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the saved photo instead of initials', (tester) async {
    await db.doc('users/learner-1/profile/photo').set({'jpeg': Blob(_png)});
    await tester.pumpWidget(_host(const ProfileAvatar(radius: 30, initials: 'AL', photoUrl: null)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('AL'), findsNothing);
  });

  testWidgets('falls back to initials when the bytes cannot be decoded', (tester) async {
    await db.doc('users/learner-1/profile/photo').set({'jpeg': Blob(Uint8List.fromList([1, 2, 3]))});
    await tester.pumpWidget(_host(const ProfileAvatar(radius: 30, initials: 'AL', photoUrl: null)));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('AL'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/profile_avatar_test.dart` — Expected: FAIL, file missing.
- [ ] **Step 3: Implement** `lib/screens/profile_avatar.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'profile_photo.dart';

/// The learner's avatar: their own photo, else the sign-in provider's photo
/// (Google), else initials. Any image that fails to load shows initials, so a
/// bad photo can never break the screen it sits on.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.radius,
    required this.initials,
    required this.photoUrl,
    this.fontSize = 22,
  });

  final double radius;
  final String initials;
  final String? photoUrl;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Uint8List?>(
      stream: ProfilePhotoService.watch(),
      builder: (context, snap) {
        final custom = snap.data;
        final fallback = _initials();
        final Widget child;
        switch (avatarSourceFor(custom: custom, photoUrl: photoUrl)) {
          case AvatarSource.custom:
            child = Image.memory(custom!,
                fit: BoxFit.cover, gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback);
          case AvatarSource.provider:
            child = Image.network(photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback);
          case AvatarSource.initials:
            child = fallback;
        }
        return SizedBox.square(
          dimension: radius * 2,
          child: ClipOval(child: child),
        );
      },
    );
  }

  Widget _initials() => ColoredBox(
        color: AppColors.primary,
        child: Center(
          child: Text(initials,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700)),
        ),
      );
}
```

- [ ] **Step 4: Run** the test — Expected: PASS (3).
- [ ] **Step 5: Commit** `lib/screens/profile_avatar.dart test/profile_avatar_test.dart`.

### Task 4: Wire into Profile (editable) and Home (display)

**Files:**
- Modify: `lib/screens/profile_screen.dart` (header `CircleAvatar` near line 1147; add `_editPhoto`)
- Modify: `lib/screens/home_screen.dart` (sheet `CircleAvatar` near line 243)

**Interfaces — Consumes:** `ProfileAvatar`, `ProfilePhotoService.save/remove/watch`, `isAcceptablePhoto`.

- [ ] **Step 1: Home** — replace the sheet's `CircleAvatar(radius: 30, …)` with:

```dart
            ProfileAvatar(
              radius: 30,
              initials: _getFirstName().isNotEmpty
                  ? _getFirstName()[0].toUpperCase()
                  : 'U',
              photoUrl: FirebaseAuth.instance.currentUser?.photoURL,
            ),
```

and add `import 'profile_avatar.dart';`.

- [ ] **Step 2: Profile header** — replace the header `CircleAvatar(radius: 44, …)` with a tappable avatar carrying a camera badge:

```dart
              Semantics(
                button: true,
                label: 'Change profile photo',
                child: GestureDetector(
                  onTap: _editPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(
                        radius: 44,
                        initials: _getInitials(),
                        fontSize: 26,
                        photoUrl: FirebaseAuth.instance.currentUser?.photoURL,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.border),
                          ),
                          child: Icon(CupertinoIcons.camera_fill,
                              size: 14, color: theme.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
```

- [ ] **Step 3: Profile action sheet** — add to `_ProfileScreenState` (imports: `package:image_picker/image_picker.dart`, `profile_avatar.dart`, `profile_photo.dart`):

```dart
  Future<void> _editPhoto() async {
    HapticFeedback.selectionClick();
    final hasCustom = await ProfilePhotoService.watch().first != null;
    if (!mounted) return;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Profile photo'),
        message: const Text('Only you can see your photo.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'choose'),
            child: const Text('Choose photo'),
          ),
          if (hasCustom)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: const Text('Remove photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    try {
      if (choice == 'remove') {
        await ProfilePhotoService.remove();
      } else if (choice == 'choose') {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 256,
          maxHeight: 256,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        if (file == null) return; // cancelled
        final bytes = await file.readAsBytes();
        if (!isAcceptablePhoto(bytes)) {
          _showToast('That photo is too large. Try another one.');
          return;
        }
        await ProfilePhotoService.save(bytes);
      }
    } catch (e) {
      debugPrint('Profile photo update failed: $e');
      _showToast('Could not update your photo. Check your connection.');
    }
  }
```

- [ ] **Step 4: Run** `flutter analyze` and `flutter test` — Expected: zero issues, all pass.
- [ ] **Step 5: Commit** `lib/screens/profile_screen.dart lib/screens/home_screen.dart`.

### Task 5: Security rules + probe cases

**Files:**
- Modify: `firestore.rules` (inside `match /users/{uid}`, after the progress block)
- Modify: `tools/security/probe_rules.js`

- [ ] **Step 1: Rules**

```
      // Private profile photo: users/{uid}/profile/photo. Owner only, and
      // capped at 150 KB to match kMaxProfilePhotoBytes in the app.
      match /profile/photo {
        allow read, delete: if isOwner(uid);
        allow create, update: if isOwner(uid)
          && request.resource.data.keys().hasOnly(['jpeg', 'updatedAt'])
          && request.resource.data.jpeg is bytes
          && request.resource.data.jpeg.size() <= 150 * 1024;
      }
```

- [ ] **Step 2: Probe** — add after PC-4 (a positive control) and after AB-14 (three abuse cases). Base64 for REST `bytesValue`:

```js
      const small = Buffer.alloc(64, 7).toString('base64');
      r = await patch(a.token, `users/${a.uid}/profile/photo`, { jpeg: { bytesValue: small } }, ['jpeg']);
      record('PC-5', 'own small profile photo writable', r.status, r.ok);
```

```js
    r = await get(a.token, `users/${b.uid}/profile/photo`);
    record('AB-16', 'reading another user profile photo refused', r.status, r.status === 403);
    const big = Buffer.alloc(150 * 1024 + 1, 7).toString('base64');
    r = await patch(a.token, `users/${a.uid}/profile/photo`, { jpeg: { bytesValue: big } }, ['jpeg']);
    record('AB-17', 'oversize profile photo refused', r.status, r.status === 403);
    r = await patch(a.token, `users/${a.uid}/profile/photo`, { jpeg: { bytesValue: Buffer.alloc(8).toString('base64') }, subscriptionPlan: { stringValue: 'all' } }, ['jpeg', 'subscriptionPlan']);
    record('AB-18', 'extra fields on the profile photo refused', r.status, r.status === 403);
```

- [ ] **Step 3: Commit** `firestore.rules tools/security/probe_rules.js`.
- [ ] **Step 4 (USER):** `! firebase deploy --only firestore:rules`, then run the probe (`node tools/security/run_probe.js`) — Expected: PC-5 PASS, AB-16/17/18 PASS; AB-15 still FAIL (known F-02).

### Task 6: Account deletion removes everything

**Files:**
- Modify: `functions/account.js`
- Test: `functions/test/account.test.js`

- [ ] **Step 1: Write the failing test** (stubs both modules through `require.cache` before loading `account.js`):

```js
const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

function stub(id, exports) {
  const file = require.resolve(id, { paths: [path.join(__dirname, "..")] });
  require.cache[file] = { id: file, filename: file, loaded: true, exports };
}

test("deleteAccount removes the whole user tree, then the Auth record", async () => {
  const calls = [];
  const userRef = { path: "users/u1" };
  stub("firebase-functions/v2/https", {
    onCall: (handler) => handler,
    HttpsError: class extends Error {},
  });
  stub("firebase-admin", {
    firestore: () => ({
      collection: () => ({ doc: (id) => (assert.equal(id, "u1"), userRef) }),
      recursiveDelete: async (ref) => calls.push(["recursiveDelete", ref.path]),
    }),
    auth: () => ({ deleteUser: async (uid) => calls.push(["deleteUser", uid]) }),
  });
  delete require.cache[require.resolve("../account.js")];
  const { deleteAccount } = require("../account.js");

  assert.deepEqual(await deleteAccount({ auth: { uid: "u1" } }), { ok: true });
  assert.deepEqual(calls, [["recursiveDelete", "users/u1"], ["deleteUser", "u1"]]);
});
```

- [ ] **Step 2: Run** `cd functions && npm test` — Expected: FAIL (`recursiveDelete` never called; the hand walk calls `userRef.collection`, which the stub lacks).
- [ ] **Step 3: Implement** — replace the progress loop and `userRef.delete()` with:

```js
  // Every subcollection goes: progress, per-module attempt receipts, the
  // profile photo, and anything added later. The old hand-written walk knew
  // only about progress and left the rest behind.
  await db.recursiveDelete(userRef);
```

- [ ] **Step 4: Run** `npm test` and `node -e "require('./index.js')"` — Expected: all pass, no load error.
- [ ] **Step 5: Commit** `functions/account.js functions/test/account.test.js`.

### Task 7: Full verification

- [ ] Mutation checks: flip `avatarSourceFor` precedence; raise the cap by 1; remove `ClipOval` errorBuilder fallback; revert `recursiveDelete` — each must fail a test.
- [ ] `flutter analyze` + `flutter test` with `tools/screenshots/fixture_content.dart` moved aside (CI conditions), then restored.
- [ ] `python -m unittest discover -s tools/ios -p 'test_*.py'`.
- [ ] Push feature branch; USER fast-forwards master and deploys rules; device check on the next build.
