/// Where the content on screen actually came from.
///
/// The lesson and quiz screens each carry a built-in sample set and fell back
/// to it on any Firestore failure, with no signal that they had. The
/// 2026-09-11 audit found `flashcards` returning 403 to every account tested,
/// while the app rendered flashcards as though nothing were wrong — so a
/// backend problem looked exactly like a working product, to the user and to
/// us.
///
/// Making the origin a value the caller has to handle is the fix. A silent
/// `catch` that swaps in sample content is invisible; a returned
/// [ContentOrigin] is not.
library;

enum ContentOrigin {
  /// Real content, returned by the server.
  live,

  /// Previously downloaded course content belonging to this account.
  cached,

  /// The built-in sample set. The server refused the read, or had nothing.
  /// The user is not looking at the course they enrolled in.
  substitute,

  /// Nothing to show: no server content and no sample set. The caller must
  /// render an error rather than an empty lesson that looks complete.
  unavailable,
}

class ContentResult<T> {
  const ContentResult(this.items, this.origin);

  final List<T> items;
  final ContentOrigin origin;

  /// True only when sample content stood in for the real thing. Deliberately
  /// false for [ContentOrigin.unavailable] — nothing was substituted there,
  /// because there was nothing to substitute.
  bool get isSubstitute => origin == ContentOrigin.substitute;

  bool get canRecordProgress =>
      items.isNotEmpty &&
      (origin == ContentOrigin.live || origin == ContentOrigin.cached);
}

/// Decide what to show and say honestly where it came from.
///
/// Pass `null` for [fetched] when the read threw — a permission denial, an
/// offline device, a malformed document. An empty list means the read
/// succeeded and the server genuinely had nothing, which is a different cause
/// with the same consequence for the reader: this is not the real content.
ContentResult<T> resolveContent<T>({
  required List<T>? fetched,
  required List<T> fallback,
}) {
  if (fetched != null && fetched.isNotEmpty) {
    return ContentResult<T>(fetched, ContentOrigin.live);
  }
  if (fallback.isNotEmpty) {
    return ContentResult<T>(fallback, ContentOrigin.substitute);
  }
  return ContentResult<T>(const [], ContentOrigin.unavailable);
}
