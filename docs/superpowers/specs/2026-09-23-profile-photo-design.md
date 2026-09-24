# Profile photo — design

Date: 2026-09-23 · Status: approved in conversation, awaiting spec review

## Goal

Let a learner set a profile photo that follows their account across devices,
on the free Spark plan (no Cloud Storage, which needs Blaze).

The photo is **private to its owner**. B1nary has no leaderboards, friends or
public profiles, so no other user can see it. That keeps it out of App Review
Guideline 1.2 (user-generated content shown to others needs moderation).

## What the user sees

- The Profile header avatar gets a small camera badge. Tapping the avatar opens
  a Cupertino-style action sheet: **Choose photo**, **Remove photo** (only when a
  custom photo exists), **Cancel**.
- **Choose photo** opens the system photo picker (library only, no camera). The
  new photo shows immediately in the Profile header and in the Home profile
  sheet.
- Precedence, everywhere an avatar is drawn:
  1. the custom photo,
  2. otherwise `FirebaseAuth.currentUser.photoURL` (populated for Google
     sign-in; Apple never supplies one),
  3. otherwise initials, exactly as today.
- Guests may set a photo. Linking a guest keeps the uid, so the photo survives
  the upgrade.

## Storage

- `image_picker` 1.2.3 with `maxWidth: 256, maxHeight: 256, imageQuality: 80,
  requestFullMetadata: false` downsizes natively and returns JPEG bytes
  (~20–40 KB). No cropping: the circle uses `BoxFit.cover`.
- Stored as a Firestore `Blob` in its own document
  **`users/{uid}/profile/photo`** `{ jpeg: <bytes>, updatedAt: serverTimestamp }`,
  not on `users/{uid}`. The main user doc is streamed by `statsStream()` and
  re-delivered on every progress write; carrying 30 KB on it would multiply
  every one of those snapshots.
- The client rejects anything over **150 KB** before writing (message shown,
  old photo kept).
- **Remove photo** deletes the document.

## Security rules (production change — must be deployed)

Inside `match /users/{uid}`:

```
match /profile/photo {
  allow read, delete: if isOwner(uid);
  allow create, update: if isOwner(uid)
    && request.resource.data.keys().hasOnly(['jpeg', 'updatedAt'])
    && request.resource.data.jpeg is bytes
    && request.resource.data.jpeg.size() <= 150 * 1024;
}
```

Deployed with `firebase deploy --only firestore:rules`. Auto mode blocks Claude
from deploying production; the user runs it. Verified afterwards with
`tools/security/run_probe.js`: a positive control (owner writes a small photo)
must succeed, and a cross-user read, an oversize write and an extra-field write
must each be denied.

## Account deletion

`functions/account.js` deletes only the `progress` tree by hand, and misses the
`attempts` subcollection under each module (quiz receipts) as well as the new
photo. Replace the hand-rolled walk with `db.recursiveDelete(userRef)`
(firebase-admin 13), which removes every subcollection. Functions are still
undeployed (Spark), so this is correct-in-waiting. A `node -e
"require('./index.js')"` smoke check guards the load.

## Crash-proofing (iOS)

`image_picker_ios` links Photos and camera APIs. Uploads that reference them
without purpose strings are rejected (ITMS-90683), and a runtime permission
request without one terminates the app. Add to `Info.plist`:

- `NSPhotoLibraryUsageDescription` — "B1nary uses a photo you choose as your
  profile picture."
- `NSCameraUsageDescription` — "B1nary can use the camera for your profile
  picture." (camera is not offered; the key exists so the upload is accepted)

`test/ios_native_crash_guards_test.dart` gains a test that both keys exist and
are non-empty.

## Components

- `lib/screens/profile_photo.dart`
  - `enum AvatarSource { custom, provider, initials }` and pure
    `AvatarSource avatarSourceFor({Uint8List? custom, String? photoUrl})`.
  - `const int kMaxProfilePhotoBytes = 150 * 1024;` and pure
    `bool isAcceptablePhoto(Uint8List bytes)`.
  - `ProfilePhotoService` over `ServiceBackend` Firestore: `Stream<Uint8List?>
    watch()`, `Future<void> save(Uint8List)`, `Future<void> remove()`.
- `lib/screens/profile_avatar.dart` — `ProfileAvatar(radius, initials)` widget:
  listens to `watch()`, applies precedence, `Image.memory` / `Image.network`
  with `errorBuilder` falling back to initials.
- `profile_screen.dart` header and `home_screen.dart` sheet swap their
  `CircleAvatar` for `ProfileAvatar`. Only Profile gets the edit badge and
  action sheet.

## Error handling

- Picker cancelled → nothing happens.
- Too large / write failed / offline → a toast via the screen's existing
  `_showToast`; the previous avatar stays.
- Unreadable bytes or a failed network image → initials.

## Testing

- Unit: `avatarSourceFor` precedence (all three sources), `isAcceptablePhoto`
  at the boundary, `ProfilePhotoService` save/watch/remove against
  `FakeFirebaseFirestore`.
- Widget: `ProfileAvatar` renders initials, a memory image, and falls back to
  initials on corrupt bytes.
- Guard: Info.plist purpose strings.
- Mutation check each new assertion (per verify-the-verifier).
- Device: pick, relaunch, remove on the next TestFlight build.

## Out of scope

Cropping, the camera, showing photos to other users, Cloud Storage.
