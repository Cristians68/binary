/// How Delete account re-confirms that the person asking owns the account.
///
/// The screen used to know two cases: Google, and "everyone else types a
/// password". A guest has no password, and neither does an account made with
/// Sign in with Apple, so both were shown a password box they could never
/// satisfy and could not delete their account at all — Guideline 5.1.1(v).
///
/// Re-confirmation guards against someone holding an unlocked phone; it is not
/// the authorisation. `deleteAccount` acts on the verified ID token of the
/// session that calls it. So an account with nothing to re-enter gets [none]
/// rather than a prompt it cannot answer.
enum DeletionReauth {
  /// Nothing to re-enter: a guest, or a provider this app does not offer.
  none,

  /// Run Sign in with Apple again. This also yields the authorization code
  /// that revoking the account's Apple token needs.
  apple,

  google,

  password,
}

/// Picks the re-confirmation for an account from its linked provider ids
/// (`User.providerData[].providerId`).
///
/// Apple wins whenever it is linked: deleting an account that uses Sign in
/// with Apple must revoke its Apple token, and only a fresh Apple sign-in
/// produces the code revocation needs.
DeletionReauth deletionReauthFor(Iterable<String> providerIds) {
  final ids = providerIds.toSet();
  if (ids.contains('apple.com')) return DeletionReauth.apple;
  if (ids.contains('google.com')) return DeletionReauth.google;
  if (ids.contains('password')) return DeletionReauth.password;
  return DeletionReauth.none;
}
