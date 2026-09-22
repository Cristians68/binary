# iOS Google sign-in crash audit

## Full audit — 2026-09-22, version 1.0.3

Reported again: on the installed iPhone build, tapping Google closes the app to
the home screen. That symptom is a **native process termination**. No Dart
handler in this app can see it, which is why four previous audits ended by
asking for a `.ips` file instead of naming a cause.

### What this audit established

Checked and **cleared** as the cause — each is now covered by a test:

- The iOS callback configuration is correct and self-consistent. `GIDClientID`,
  `DefaultFirebaseOptions.ios.iosClientId`, the reversed-client URL scheme, the
  Firebase fallback scheme `app-1-221875967372-ios-ef2266196153b474a372a9`,
  `GoogleService-Info.plist` and the bundle identifier all agree.
  `test/firebase_platform_config_test.dart` now asserts this.
- `google_sign_in_ios` 6.3.3 no longer re-raises. Its `signInWithScopeHint:`
  and `addScopes:` wrap the call in `@try/@catch` and return a `FlutterError`.
  The `[e raise]` path described in the previous audit is gone.
- `SceneDelegate.swift` is a plain `FlutterSceneDelegate` subclass, is listed in
  the Xcode `Sources` build phase, and is named correctly by
  `UISceneDelegateClassName` in `Info.plist`.
- The Dart layer cannot crash the process. Every Google entry point catches
  `GoogleSignInException`, `PlatformException`, `FirebaseAuthException` and a
  bare `catch`. `_onSignInSuccess` swallows its own failures.
- 540 Flutter tests pass, `flutter analyze` reports no issues, and 7 Python
  archive-verifier tests pass.

### Why the cause is still not named

The plugin's `@try/@catch` is **weaker protection than it looks**. Its podspec
requires `GoogleSignIn ~> 9.0`, and the 9.x Google SDK is written in Swift. A
Swift `fatalError`, trap or force-unwrap is not an `NSException` and is not
catchable by Objective-C `@catch`, so the plugin's handler cannot intercept it.

`ios/Podfile.lock` is **not committed**, so CocoaPods re-resolves the native
GoogleSignIn SDK on every CI machine. Two builds from the identical Dart source
can therefore contain different native SDKs. The verifier only requires
`>= 9.0.0`. This is the most likely reason the crash has appeared to come and
go across builds.

Naming the faulting frame still requires a crash report — but the app now
produces one by itself (below) instead of depending on a manual export.

### Changed in 1.0.3

1. **Native crash reporting** (`lib/crash_reporting.dart`). `firebase_crashlytics`
   installs a native handler, so a Swift `fatalError`, an uncaught `NSException`
   or a signal uploads itself. `FlutterError.onError`, `PlatformDispatcher.onError`
   and the `runZonedGuarded` handler in `main()` feed the same report. Disabled
   on web (no implementation) and in debug builds.
2. **Breadcrumbs through the Google flow.** `CrashReporting.trail` marks each
   native stage — initializing, clearing the account selection, presenting the
   chooser, reading the identity token, exchanging it with Firebase. When the
   process is killed, the last breadcrumb names the stage that killed it. This
   is the single question no previous audit could answer.
3. **A transient initialization failure is no longer permanent.**
   `NativeGoogleAuth` cached the `initialize()` future with `??=`, including a
   *rejected* one. One failure — no network on first launch, a slow keychain —
   left every later tap awaiting the same dead future, so Google stayed broken
   until the app was force-quit while Apple and email kept working. A failed
   attempt is now forgotten and retried; a successful one is still made once.
4. **CI uploads dSYMs to Crashlytics**, so reports arrive symbolicated rather
   than as raw addresses. Deliberately non-fatal: a symbol-upload failure must
   not discard a signed, verified build.
5. **The release verifier now refuses an iOS build with no crash reporting.**
6. **Android `google-services.json` named the wrong package.** It declared
   `com.example.binary`, the Flutter template default, while the app ships as
   `com.cristians.b1nary`. The `com.google.gms.google-services` plugin is
   applied and fails the build outright on that mismatch. Nothing caught it
   because Android is not built in CI.

### Still open — needs the Firebase console, not the repo

- **Android has no OAuth client.** `google-services.json` carries
  `"oauth_client": []`, and no `serverClientId` is passed anywhere. Google
  sign-in on Android cannot return an identity token in this state. Register the
  Android app and its SHA-1/SHA-256 fingerprints, add a Web client, then re-run
  `flutterfire configure`. The corrected package name above only unblocks the
  build; it does not create the client. Confirm the console really holds
  `com.cristians.b1nary` for app id
  `1:221875967372:android:2c008d4d146758efa372a9`.
- **`ios/Podfile.lock` is not committed**, so native pod versions are not
  reproducible. It cannot be generated on Windows. Commit the one produced by
  the next macOS CI build — it is already retained as a build artifact.
- **`ios/Runner/GoogleService-Info.plist` is tracked but never bundled.** It
  appears in no Resources build phase, so it does not reach the app. Firebase is
  configured from `DefaultFirebaseOptions` in Dart, so nothing is broken today,
  and the archive verifier already rejects a bundled copy that conflicts. It is
  a decoy that has misled at least one previous audit, and CI uses it for the
  dSYM upload.

### Next step

Build `feature/notifications-and-streaks` with `ios-testflight`, install it, and
tap Google. If it still terminates, the report is now in Firebase Crashlytics
with the faulting frame and the breadcrumb naming the stage — no manual `.ips`
export. Retain the build number from `ios-auth-release.json`.

---

## Earlier audit — 2026-09-20

The repository contains two native crash paths in older Google sign-in
integrations. At the initial audit, the newest fix was committed locally but
absent from both live GitHub branches. The installed iPhone build and its native crash report were
not available, so this audit distinguishes source findings from a confirmed
diagnosis of that particular crash.

## Follow-up after another reported crash — version 1.0.2

The earlier fix was subsequently pushed in the history of `cdff36a`. The user
started a Codemagic build and then reported another immediate Google crash,
plus the app opening into a guest session. The successful build's revision,
installed TestFlight version/build and native crash report have not been
provided. The new report therefore does not establish which Google integration
was running. The native crash remains **unverified on the device**.

The guest behavior has a confirmed source cause: `_AppEntry` resumed every
persisted Firebase session, including anonymous sessions, directly into the
app. Version 1.0.2 changes this behavior:

- A restored guest sees the sign-in choices. Its identity stays alive so Google,
  Apple or email can link it without first signing out.
- Explicitly choosing Continue as guest reuses that identity and its progress.
  A stale guest action cannot replace a registered account.
- A guest already inside the app can choose any sign-in method from Profile.

The iOS OAuth client is now explicit in both Firebase options and native Google
initialization. Both the Google reversed-client scheme and Firebase fallback
scheme are registered. These close configuration gaps found in the source;
they are not evidence of the exception on the user's phone.

The project now explicitly uses its existing CocoaPods integration. The local
generated plugin configuration had Swift Package Manager disabled, while the
project did not pin that choice for fresh CI machines. Flutter enables Swift
Package Manager by default from 3.44. This change removes build drift; it is
not a confirmed cause of the reported crash.
[Flutter project configuration](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)

The `ios-testflight` workflow now stamps the source revision and resolved
Google plugin/SDK versions into the app and checks the exported IPA's plist
before upload. It rejects missing callbacks, mismatched client/bundle/build
identifiers, stale revision markers and conflicting bundled Firebase config.
It retains `ios-auth-release.json`, both lockfiles and the archive's dSYMs for
matching and diagnosing the installed build. The verifier also requires the
expected CocoaPods configuration, plugin 6.3.3 or newer and Google SDK 9 or newer.

Validation completed locally: **534 Flutter tests passed**, `flutter analyze`
reported **no issues**, and **7 Python archive-verifier tests passed**. The new
guest widget regression exercises the real app entry and Google button, with
Firebase and Google's native platform mocked. The Python tests inspect
synthetic IPA archives, including binary plists and deliberate configuration
errors. Neither test suite runs the native Google sheet or a signed iOS app.

The next diagnostic input is the existing crash report, not another assumption
from a successful build. On the iPhone, retrieve the latest Runner/B1nary
report under Settings → Privacy & Security → Analytics & Improvements →
Analytics Data. Retain its version/build, exception, termination reason and
faulting-thread backtrace, or the complete `.ips` file. A TestFlight crash can
also be obtained through Xcode's crash organizer.
[Apple crash-report instructions](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs)

## Release state at the initial audit

Both the GitHub branches API and `git ls-remote --heads origin` returned:

| Location | Commit | Google sign-in implementation |
| --- | --- | --- |
| Remote `master` | `c196c047c88739dd64dabbd9da80b9f91e17db4c` | Firebase provider flow first; Google iOS plugin 5.9.0 as fallback |
| Remote `feature/notifications-and-streaks` | `f73ab536d4b9f9c37ff57ac065603b199315eb68` | Native Google flow; Google iOS plugin 5.9.0 |
| Local feature branch | `4de8e5dc255899359121fe0e5e496c221db2ee73` | Native Google flow; Google iOS plugin 6.3.3 |

The local branch was four commits ahead of its remote. A Codemagic build
from either remote revision above cannot contain `4de8e5d`. The previous
[fix notes](AUTH-FIXES.md) also record that no push or iOS build was performed.
The actual TestFlight build number is generated by CI; pubspec's suffix does
not identify the installed build.

## Confirmed configuration defect in master: Firebase terminates the process

In `c196c04`, tapping Google on iOS enters `_googleViaFirebaseProvider`, then
`signInWithProvider` or `linkWithProvider`. Firebase is initialized from
`DefaultFirebaseOptions`, whose iOS options omit `iosClientId`.
`GoogleService-Info.plist` is absent from the checked-in Xcode resources.

Firebase iOS 11.15.0 therefore selects this fallback callback scheme:

```text
app-1-221875967372-ios-ef2266196153b474a372a9
```

`master` registers only the Google reversed-client scheme. The fallback scheme
above is missing. Firebase's `OAuthProvider.getCredentialWith` checks it and
calls Swift `fatalError` before presenting authentication. The expected message
is `Please register custom URL scheme ... in the app's Info.plist file.`
The SDK selects the scheme from Firebase options; `GIDClientID` in Info.plist
does not supply those options. See [Firebase's SDK implementation](https://github.com/firebase/firebase-ios-sdk/blob/11.15.0/FirebaseAuth/Sources/Swift/AuthProvider/OAuthProvider.swift#L105).

A Swift fatal error terminates the process; the Dart exception handler and
fallback to Google sign-in cannot recover. This is an immediate-crash defect
for a build using the checked-in master configuration. CI-injected resources
or configuration must be checked in the actual archive before attributing a
particular installed build to this path.

The feature branch already removed this provider flow in `e06cc53`. The local
fix retains the documented native Google SDK → identity token → Firebase
credential flow. [Firebase Flutter integration guide](https://firebase.google.com/docs/auth/flutter/federated-auth#google)

## Additional native crash exposure on both remote branches

`google_sign_in_ios` 5.9.0 locates its presenter through the deprecated
`UIApplication.keyWindow.rootViewController`. The app uses `UIScene`.
If the lookup returns nil, the Google SDK throws a native exception for the
missing presenter. The plugin also catches configuration exceptions and then
calls `[e raise]`, terminating the app despite reporting an error to Dart.
The native SDK also throws for a missing client configuration or callback
scheme. [Google SDK checks](https://github.com/google/GoogleSignIn-iOS/blob/8.0.0/GoogleSignIn/Sources/GIDSignIn.m#L1095)

The source confirms this exposure; it does not establish that the presenter
was nil on the user's phone. A matching crash report would identify
`GIDSignIn`, `assertValidPresentingViewController`, or the missing configuration
or scheme exception.

Local `4de8e5d` upgrades to 6.3.3, which uses the Flutter registrar's view
controller and registers a scene delegate. Its exception handler returns an
error without rethrowing it. The app's manual URL forwarding was removed.
The upstream changelog records configuration-crash handling in 6.0.1 and scene
support in 6.3.0. [Plugin changelog](https://pub.dev/packages/google_sign_in_ios/changelog)

## Checks completed during the initial audit

- The read-only live Firebase audit returned Google provider enabled, with
  client ID and client secret present. It did not expose credentials or user
  records and does not prove that every OAuth setting is valid.
- The local Google native client ID, reversed callback scheme, and bundle ID
  agree with the local Firebase iOS configuration. That agreement does not
  satisfy the different Firebase provider callback on master.
- Re-ran `flutter test --no-pub test/native_google_auth_test.dart
  test/auth_result_test.dart test/auth_cancellation_test.dart
  test/codemagic_config_test.dart --reporter expanded`: **40 tests passed**.
  These are Dart tests and configuration checks; the Google native platform is
  mocked. They do not exercise UIKit, Swift fatal errors, or a signed iOS app.
- No iOS archive or `.ips`/`.crash` report was available in the project.
  No runtime code, Firebase settings, remote branches, or releases were changed
  during this audit.

## Required release verification

Use the `feature/notifications-and-streaks` branch, which contains the complete
authentication changes. Rebuilding the old `master` revision repeats the defective
provider flow. The follow-up release is version **1.0.2**; the CI workflow assigns the
next unused TestFlight build number.

Build the latest feature-branch revision with the `ios-testflight` workflow
from `codemagic.yaml`, and retain `ios-auth-release.json` with the generated
build number. Install that exact build, then exercise Google sign-in,
cancellation/retry, and sign-out/sign-in on an iPhone. Also verify that a
restored guest sees the welcome screen and can link Google without signing
out or losing progress. A green archive check alone does not verify these
native runtime behaviors.

For the already reported crash, retain the TestFlight version/build and native
crash report. `OAuthProvider.getCredentialWith` plus the missing callback
message would confirm the master defect; a `GIDSignIn` presenter/configuration
exception would identify the older plugin path. Neither should be described
as a device-confirmed root cause without that evidence.
