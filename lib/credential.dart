/// Completion credential IDs — one per learner, per course.
///
/// WHY THIS EXISTS
/// ---------------
/// The certificate screen printed no credential at all. The single `certId` it
/// had was the LinkedIn deep-link parameter, and its value was the raw course
/// id — the same string for every learner who ever finished that course. A
/// credential that every holder shares identifies nobody, which makes it not a
/// credential.
///
/// DESIGN
/// ------
/// `BA-<COURSE>-XXXX-XXXX-XXXX`, where the trailing 12 hex digits are the first
/// 48 bits of `SHA-256("<uid>:<courseId>")`, uppercased and grouped.
///
///   * **Unique per learner and per course** — different uid or different
///     course, different digest.
///   * **Stable forever** — it is derived, not generated, so re-opening the
///     certificate a year later reproduces the same ID with nothing stored and
///     nothing to migrate. A credential that changes between viewings is
///     worthless.
///   * **Does not leak the uid.** This lands on a public LinkedIn profile.
///     SHA-256 is preimage resistant, so the digest reveals nothing about the
///     account, and the uid is never printed.
///   * **Verifiable by us.** Given a uid and a course, the ID recomputes
///     exactly, so a support claim can be checked without a lookup table.
///
/// 48 bits makes an accidental collision negligible: even at 100,000 holders of
/// a single course the birthday probability is under one in a hundred thousand,
/// and a collision would require the same course as well.
///
/// The course segment comes from `CourseInfo.code`, which is pinned by
/// `test/course_catalog_test.dart` for the same reason `id` and `tag` are —
/// changing one invalidates every certificate already issued.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'course_catalog.dart';

/// Prefix on every credential this app issues.
const String kCredentialPrefix = 'BA';

/// Course segment used when a course is not in the catalogue.
///
/// A newly seeded course can be completed before its catalogue entry ships.
/// Issuing `BA-GEN-...` is better than issuing nothing: the digest half still
/// identifies the holder and the course uniquely.
const String kUncataloguedCourseCode = 'GEN';

/// Hex digits of the digest kept. 12 → 48 bits.
const int _digestHexLength = 12;

/// The credential ID for one learner's completion of one course.
///
/// Returns an empty string when [uid] or [courseId] is empty, because there is
/// no honest credential to print for an unidentified holder — the caller shows
/// nothing rather than a plausible-looking ID that means nothing.
String courseCredentialId({
  required String uid,
  required String courseId,
}) {
  if (uid.isEmpty || courseId.isEmpty) return '';

  final code = courseInfo(courseId)?.code ?? kUncataloguedCourseCode;

  // The separator matters: without it, ("ab", "c") and ("a", "bc") would hash
  // to the same digest. A colon cannot appear in a Firebase uid or a Firestore
  // document id, so the split point is unambiguous.
  final digest = sha256.convert(utf8.encode('$uid:$courseId')).toString();
  final body = digest.substring(0, _digestHexLength).toUpperCase();

  final groups = <String>[
    for (var i = 0; i < _digestHexLength; i += 4) body.substring(i, i + 4),
  ];

  return '$kCredentialPrefix-$code-${groups.join('-')}';
}
