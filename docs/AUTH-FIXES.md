# Authentication fixes — 1.0.1

Follow-up: the [2026-09-20 iOS crash audit](IOS-GOOGLE-SIGNIN-AUDIT.md) found
that this fix had not been pushed at the time of the audit and identified an
additional Firebase callback configuration crash on remote `master`.

## iOS Google sign-in

The previous lockfile used `google_sign_in_ios` 5.9.0. Its native code looked
up the deprecated application key window and rethrew Objective-C exceptions
after reporting an error to Dart. A Dart `try/catch` or `runZonedGuarded` cannot
prevent that native process termination.

The app now uses `google_sign_in` 7.2.0 with `google_sign_in_ios` 6.3.3. The
iOS implementation includes native configuration-error handling and UIScene
support. Flutter delivers OAuth callbacks through the plugin; the app's old
manual forwarding in AppDelegate and SceneDelegate has been removed.

See the [upstream changelog](https://pub.dev/packages/google_sign_in_ios/changelog),
especially 6.0.1 and 6.3.0.

`NativeGoogleAuth` initializes the SDK once, clears the previous account
selection, and obtains an identity token for Firebase. Sign-in and Google
reauthentication before account deletion use the same client. Cancellation
returns to the screen; configuration errors show guidance and an error code.
Web continues to use Firebase's popup flow.

These changes address confirmed problems in the old integration. The exact
crash reported on the user's iPhone has not been reproduced or matched to a
native crash report on this Windows machine.

## Sign-out and account switching

The unfinished change that navigated away before signing out did not guarantee
cleanup: Flutter keeps the outgoing route alive until its animation finishes.

All account document and progress listeners now go through `ServiceBackend`
and `UserStreams`. Sign-out waits for their cancellation before clearing
Firebase credentials. Streams created before or during the transition cannot
reattach to the old account. Switching from a guest to an existing provider
account uses the same cleanup. Home and Profile share a sign-out action that
navigates after success and reports a failure on the current screen.

The startup zone guard remains as last-resort handling for uncaught Dart
futures; it is not a substitute for cancelling listeners or fixing native code.

## Verification and device follow-up

Paused at the user's request on 2026-09-20 after completing the local changes.

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 527 tests passed, including
  15 new authentication/listener regression tests.
- `flutter build web --release --no-pub`: succeeded; `build/web/version.json`
  confirms version `1.0.1`, build `53`. The existing RevenueCat web dependency
  emits a Wasm dry-run warning; the JavaScript release build succeeds.
- The additional Chrome test run was stopped during loading. Its test server
  returned HTTP 404 for `/canvaskit/chromium/canvaskit.js` and `.wasm`, although
  those files exist in the Flutter SDK cache and the release web output.
  No Chrome test-pass claim is made. Investigate the Flutter test-server asset
  routing before retrying; do not confuse this with the reported iPhone crash.
- No iOS archive, TestFlight upload, production deploy, or Git push was run.

The regression tests cover Google SDK initialization, token validation,
cancellation, configuration errors, and listener cancellation ordering,
including paused consumers and switching accounts.

A signed iOS build and physical-device verification are still required:

1. Build this commit with Codemagic's `ios-testflight` workflow. Its build
   number is calculated from App Store Connect and overrides pubspec's `+53`.
2. Install the new 1.0.1 build in TestFlight. Start Google sign-in, cancel it,
   then retry and finish choosing an account.
3. Sign out from Profile, sign in again, and repeat from Home's account sheet.
4. Confirm a guest can still create/link an account without losing progress.
5. With a disposable test account, start account deletion and cancel the
   Google account chooser. Confirm deletion stops and the account stays signed in.

If iOS still terminates the process, retain the TestFlight build number,
device/iOS version, the exact step, and the iOS crash report. Web tests cannot
establish whether a native iOS crash is fixed.
