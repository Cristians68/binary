/// Tests for how the app decides whether it is showing real course content.
///
/// The 2026-09-11 audit found that `flashcards` returned 403 to every account
/// tested — including one holding a self-granted `subscriptionPlan: "all"` —
/// and the app showed flashcards anyway. lesson_screen and quiz_screen both
/// substitute a built-in sample set on any failure, with nothing distinguishing
/// it from the course the user enrolled in.
///
/// Two failures wear the same face there: "the server refused us" and "the
/// server has nothing". Both silently became a normal-looking lesson. The point
/// of this type is that the substitution becomes a value the caller has to
/// handle, rather than a branch nobody can see from the outside.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:binary/content_source.dart';

void main() {
  group('resolveContent', () {
    const fallback = ['sample-a', 'sample-b'];

    test('uses what the server returned and calls it live', () {
      final r = resolveContent(fetched: ['real-1', 'real-2'], fallback: fallback);
      expect(r.origin, ContentOrigin.live);
      expect(r.items, ['real-1', 'real-2']);
      expect(r.isSubstitute, isFalse);
    });

    test('never prefers the sample set when real content came back', () {
      // The bug this guards is the reverse of the obvious one: a fallback that
      // wins over live data would hide the real course from paying users.
      final r = resolveContent(fetched: ['real-1'], fallback: fallback);
      expect(r.items, ['real-1']);
    });

    test('a failed read is a substitute, not a lesson', () {
      // null means the read threw — a permission denial, or offline.
      final r = resolveContent(fetched: null, fallback: fallback);
      expect(r.origin, ContentOrigin.substitute);
      expect(r.isSubstitute, isTrue);
      expect(r.items, fallback);
    });

    test('an empty server response is also a substitute', () {
      // Distinct cause, same consequence for the user: what they are reading is
      // not the content the course promised.
      final r = resolveContent(fetched: <String>[], fallback: fallback);
      expect(r.origin, ContentOrigin.substitute);
      expect(r.items, fallback);
    });

    test('reports unavailable when there is nothing to show at all', () {
      // No server content and no sample set. The caller must render an error,
      // not an empty lesson that looks finished.
      final r = resolveContent(fetched: null, fallback: <String>[]);
      expect(r.origin, ContentOrigin.unavailable);
      expect(r.items, isEmpty);
      expect(r.isSubstitute, isFalse,
          reason: 'nothing was substituted — there was nothing to substitute');
    });

    test('an empty server response with no fallback is unavailable', () {
      final r = resolveContent(fetched: <String>[], fallback: <String>[]);
      expect(r.origin, ContentOrigin.unavailable);
      expect(r.items, isEmpty);
    });
  });
}
