/// The outcome of a sign-in attempt, and why it ended that way.
///
/// Every sign-in method used to return `UserCredential?` and swallow its
/// exception, so a user tapping "cancel" and a provider that is genuinely
/// broken produced the identical result: null. The UI then showed
/// "Apple sign-in failed. Please try again." for both.
///
/// That cost real time. "Apple sign-in isn't working" arrived from a device
/// with no code, no message and nothing in it to distinguish a misconfigured
/// provider from a user backing out — while the actual reason had been printed
/// to a debug console nobody can read on a TestFlight build.
enum AuthOutcome {
  success,

  /// The user backed out. Not an error, and must never be shown as one.
  cancelled,

  /// Everything else. [AuthResult.code] carries the provider's own code.
  failed,
}

class AuthResult {
  const AuthResult._(this.outcome, {this.code, this.message});

  const AuthResult.success() : this._(AuthOutcome.success);

  const AuthResult.cancelled() : this._(AuthOutcome.cancelled);

  /// [code] should be the provider's raw code — `operation-not-allowed`,
  /// `invalid-credential`, an `AuthorizationErrorCode`, a `PlatformException`
  /// code. It is shown to the user verbatim, because the person hitting the
  /// bug is usually the only one who can see it happen.
  const AuthResult.failed({String? code, String? message})
      : this._(AuthOutcome.failed, code: code, message: message);

  final AuthOutcome outcome;
  final String? code;
  final String? message;

  bool get isSuccess => outcome == AuthOutcome.success;
  bool get isCancelled => outcome == AuthOutcome.cancelled;
  bool get isFailure => outcome == AuthOutcome.failed;

  /// What to put in front of the user. Never called for a cancellation.
  ///
  /// Leads with the plain sentence and appends the code, so a screenshot of
  /// the snackbar is enough to diagnose it.
  String displayMessage(String provider) {
    final guidance = switch (code) {
      'network-request-failed' => 'Check your connection and try again.',
      'popup-blocked' =>
        'Allow the sign-in popup in your browser, then try again.',
      'operation-not-allowed' ||
      'operation-not-supported-in-this-environment' ||
      'unauthorized-domain' ||
      'invalid-oauth-client-id' =>
        'This sign-in option is unavailable right now. You can continue with email or as a guest.',
      'account-exists-with-different-credential' =>
        'Use the sign-in method you originally chose for this email address.',
      'too-many-requests' => 'Please wait a moment before trying again.',
      'no-active-window' => 'Return to B1nary and try again.',
      _ => null,
    };
    if (guidance != null) return '$provider sign-in failed. $guidance ($code)';
    final detail = [
      if (message != null && message!.isNotEmpty) message,
      if (code != null && code!.isNotEmpty) '($code)',
    ].join(' ');

    if (detail.isEmpty) return '$provider sign-in failed. Please try again.';
    return '$provider sign-in failed: $detail';
  }

  @override
  String toString() => 'AuthResult($outcome, code: $code, message: $message)';
}

/// Provider error codes that mean the user backed out.
///
/// Firebase's web-context OAuth flow reports a cancellation as an *error*, so
/// without this a user tapping "Cancel" on the Google account chooser would be
/// told sign-in failed.
///
/// It matters more than a wording nit. [AuthService.signInWithApple] and the
/// iOS Google path both fall back to a second flow when the first one fails.
/// If a cancellation were treated as a failure, backing out of one sheet would
/// immediately raise another one the user never asked for — and backing out of
/// that would raise the first again on the next tap. A cancellation must stop
/// the chain.
const Set<String> kCancellationCodes = {
  'web-context-canceled',
  'web-context-cancelled',
  'user-canceled',
  'user-cancelled',
  'canceled',
  'cancelled',
  'popup-closed-by-user',
  'cancelled-popup-request',
  'ERROR_ABORTED_BY_USER',
  'sign_in_canceled',
  'sign_in_cancelled',
};

/// Whether [code] is a provider's way of saying "the user backed out".
bool isCancellationCode(String? code) =>
    code != null && kCancellationCodes.contains(code);
