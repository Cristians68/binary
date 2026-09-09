/// The outcome of a "Restore purchases" attempt, and why it ended that way.
///
/// Restore used to return a bare `bool`, and every failure mode collapsed into
/// `false`: a store error, a network failure, and an Apple ID that genuinely
/// owns nothing all produced the same result. All three then surfaced as
/// "No previous purchases found on this Apple ID", which is a factual claim the
/// app had not actually established — and which sends a paying customer to
/// support believing their receipt is gone.
///
/// There is a fourth state that `bool` could not express at all, and it is the
/// one that matters most here. Entitlements are written to Firestore by the
/// RevenueCat webhook, never by the client (see subscription_service.dart).
/// So the store can confirm an active purchase while the account still shows
/// no plan — during a webhook delay, or whenever the Cloud Functions that
/// receive it are not deployed. The old code returned `true` for that, closed
/// the paywall, and dropped the user back onto locked content with no
/// explanation. [RestoreOutcome.pendingActivation] names it instead.
///
/// This mirrors AuthResult, which exists for the identical reason on sign-in.
enum RestoreOutcome {
  /// The purchase was found AND the account now reflects it. Access is live.
  applied,

  /// The store confirmed an active entitlement, but the account still showed
  /// no plan after waiting for it. The purchase is safe; activation is late.
  pendingActivation,

  /// The store has nothing to restore for this Apple ID. This is the only
  /// outcome that may tell the user no purchase exists.
  nothingToRestore,

  /// The restore call itself failed. [RestoreResult.code] carries the store's
  /// own code where there is one.
  failed,
}

class RestoreResult {
  const RestoreResult(this.outcome, {this.code, this.message});

  const RestoreResult.applied() : this(RestoreOutcome.applied);
  const RestoreResult.pending() : this(RestoreOutcome.pendingActivation);
  const RestoreResult.nothing() : this(RestoreOutcome.nothingToRestore);
  const RestoreResult.failed({String? code, String? message})
      : this(RestoreOutcome.failed, code: code, message: message);

  final RestoreOutcome outcome;
  final String? code;
  final String? message;

  /// True only when access is actually usable now. Callers that close a
  /// paywall on success must gate on this and nothing looser — closing on
  /// [RestoreOutcome.pendingActivation] is what put the user back on a locked
  /// screen with no explanation.
  bool get isApplied => outcome == RestoreOutcome.applied;

  bool get isPending => outcome == RestoreOutcome.pendingActivation;
  bool get foundNothing => outcome == RestoreOutcome.nothingToRestore;
  bool get isFailure => outcome == RestoreOutcome.failed;

  /// Dialog title matching the outcome.
  String get title {
    switch (outcome) {
      case RestoreOutcome.applied:
        return 'Purchases Restored';
      case RestoreOutcome.pendingActivation:
        return 'Purchase Found';
      case RestoreOutcome.nothingToRestore:
        return 'Nothing to Restore';
      case RestoreOutcome.failed:
        return 'Restore Failed';
    }
  }

  /// What to put in front of the user.
  ///
  /// The failure case appends the store's own code, for the same reason
  /// AuthResult does: the person hitting the bug ships no logs, so a
  /// screenshot has to be enough to diagnose it.
  String get displayMessage {
    switch (outcome) {
      case RestoreOutcome.applied:
        return 'Your purchases have been restored.';
      case RestoreOutcome.pendingActivation:
        return 'We found your purchase, but your account has not finished '
            'updating yet. This usually clears within a minute — reopen the '
            'app and try again. If it does not, contact support and mention '
            'that the purchase is confirmed but not activated.';
      case RestoreOutcome.nothingToRestore:
        return 'No previous purchases were found on this Apple ID. Make sure '
            'you are signed in to the same Apple ID you bought with.';
      case RestoreOutcome.failed:
        final detail = [
          if (message != null && message!.isNotEmpty) message,
          if (code != null && code!.isNotEmpty) '($code)',
        ].join(' ');
        if (detail.isEmpty) {
          return 'Could not reach the App Store to restore your purchases. '
              'Check your connection and try again.';
        }
        return 'Could not restore purchases: $detail';
    }
  }

  @override
  String toString() => 'RestoreResult($outcome, code: $code)';
}
