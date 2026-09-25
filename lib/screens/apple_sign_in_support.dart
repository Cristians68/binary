import 'build_identity.dart';

/// How far an Apple sign-in got before it failed.
///
/// The token diagnostics in `apple_token_diagnostics.dart` only exist once
/// Apple has handed over a token AND Firebase has rejected it. Every other
/// failure — the sheet never opening, Apple erroring, Apple returning no token
/// — used to produce no support line at all, so "the token line isn't there"
/// could not be told apart from "this build doesn't have the token line".
/// The stage says which of those happened.
enum AppleSignInStage {
  /// Before the sheet: nonce generation, the native bridge being reachable.
  starting('starting'),

  /// The Apple sheet is up; waiting for Apple's answer.
  appleSheet('apple-sheet'),

  /// Apple answered, but without a usable identity token.
  appleToken('apple-token'),

  /// Apple's token is being exchanged with Firebase.
  firebase('firebase'),

  /// Firebase accepted it; finishing the profile.
  profile('profile');

  const AppleSignInStage(this.label);
  final String label;
}

/// The block "Copy details for support" hands over, shown under the error.
///
/// Always names the stage and the installed build. Holds no Apple user id,
/// email, name or token — only codes and the token's already-privacy-safe
/// check line.
String appleSupportDetails({
  required AppleSignInStage stage,
  required BuildIdentity build,
  String? code,
  Object? nativeDetails,
  String? tokenCheck,
}) {
  return [
    'stage: ${stage.label}',
    'build: ${build.describe()}',
    if (code != null && code.isNotEmpty) 'code: $code',
    if (nativeDetails != null) 'native: $nativeDetails',
    tokenCheck ??
        (stage == AppleSignInStage.firebase ||
                stage == AppleSignInStage.profile
            ? 'token: not checked'
            : 'token: none received'),
  ].join('\n');
}
