/// Tests for per-learner, per-course completion credentials.
///
/// The certificate screen printed no credential. Its only `certId` was the
/// LinkedIn deep-link parameter, set to the raw course id — identical for every
/// learner who finished that course. These tests pin the four properties that
/// make the replacement an actual credential: unique per holder, unique per
/// course, stable across viewings, and revealing nothing about the account.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:binary/course_catalog.dart';
import 'package:binary/credential.dart';

void main() {
  const uidA = 'zX1cQpLm4RbT8vNw2KdY6HsE0aFg';
  const uidB = 'p7MnB3vCx9QeL2TkW5RdZ8yUiO1s';
  const course = 'binary-ai-fundamentals';

  group('uniqueness', () {
    test('two learners of the same course get different credentials', () {
      // The exact defect: every holder used to share one string.
      expect(
        courseCredentialId(uid: uidA, courseId: course),
        isNot(courseCredentialId(uid: uidB, courseId: course)),
      );
    });

    test('one learner gets a different credential for each course', () {
      final ids = kCourseCatalog
          .map((c) => courseCredentialId(uid: uidA, courseId: c.id))
          .toList();
      expect(ids.toSet().length, ids.length,
          reason: 'two courses issued the same credential to one learner');
    });

    test('every course in the catalogue can issue one', () {
      for (final c in kCourseCatalog) {
        final id = courseCredentialId(uid: uidA, courseId: c.id);
        expect(id, isNotEmpty, reason: '${c.id} produced no credential');
        expect(id, contains('-${c.code}-'),
            reason: '${c.id} did not carry its own course code');
      }
    });
  });

  group('stability', () {
    test('the same learner and course always produce the same credential', () {
      // A credential that changes between viewings is not a credential. This is
      // why it is derived rather than randomly generated and stored.
      final first = courseCredentialId(uid: uidA, courseId: course);
      for (var i = 0; i < 50; i++) {
        expect(courseCredentialId(uid: uidA, courseId: course), first);
      }
    });

    test('the value is pinned, so a hashing change cannot pass silently', () {
      // Regenerating this constant is the same act as invalidating every
      // certificate already issued. If this test fails, that is the question
      // to answer — not a value to update.
      expect(
        courseCredentialId(uid: 'test-uid', courseId: 'binary-ai-fundamentals'),
        // Verified independently of the implementation:
        //   printf '%s' 'test-uid:binary-ai-fundamentals' | sha256sum
        //   -> 10382087631d...
        'BS-AIML-1038-2087-631D',
      );
    });
  });

  group('format', () {
    test('matches BS-CODE-XXXX-XXXX-XXXX', () {
      final id = courseCredentialId(uid: uidA, courseId: course);
      expect(
        RegExp(r'^BS-[A-Z]{2,6}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$')
            .hasMatch(id),
        isTrue,
        reason: 'unexpected credential shape: $id',
      );
    });

    test('is uppercase, so it reads the same however it is transcribed', () {
      final id = courseCredentialId(uid: uidA, courseId: course);
      expect(id, id.toUpperCase());
    });

    test('an uncatalogued course still issues a usable credential', () {
      // A course can be seeded and completed before its catalogue entry ships.
      final id = courseCredentialId(uid: uidA, courseId: 'brand-new-course');
      expect(id, startsWith('BS-$kUncataloguedCourseCode-'));
      expect(id, isNot(courseCredentialId(uid: uidB, courseId: 'brand-new-course')),
          reason: 'the holder must still be distinguished without a code');
    });
  });

  group('it reveals nothing about the account', () {
    test('the uid never appears in the credential', () {
      final id = courseCredentialId(uid: uidA, courseId: course);
      expect(id, isNot(contains(uidA)));
      // Nor any recognisable run of it — this string is published on a public
      // profile.
      for (var i = 0; i + 6 <= uidA.length; i++) {
        expect(id.toLowerCase(), isNot(contains(uidA.substring(i, i + 6).toLowerCase())));
      }
    });

    test('two uids differing by one character give unrelated credentials', () {
      final a = courseCredentialId(uid: 'user-00001', courseId: course);
      final b = courseCredentialId(uid: 'user-00002', courseId: course);
      expect(a, isNot(b));
      // The digest halves should share almost nothing; assert they are not
      // simply sequential.
      expect(a.split('-').skip(2).join(), isNot(b.split('-').skip(2).join()));
    });
  });

  group('refuses to invent a credential', () {
    test('an empty uid produces nothing rather than a plausible-looking id', () {
      expect(courseCredentialId(uid: '', courseId: course), isEmpty);
    });

    test('an empty course produces nothing', () {
      expect(courseCredentialId(uid: uidA, courseId: ''), isEmpty);
    });
  });

  group('course codes', () {
    test('every code is unique', () {
      final codes = kCourseCatalog.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length,
          reason: 'two courses sharing a code makes their credentials '
              'indistinguishable at a glance');
    });

    test('no code collides with the uncatalogued placeholder', () {
      for (final c in kCourseCatalog) {
        expect(c.code, isNot(kUncataloguedCourseCode));
      }
    });

    test('every code is short, uppercase and alphabetic', () {
      for (final c in kCourseCatalog) {
        expect(RegExp(r'^[A-Z]{2,6}$').hasMatch(c.code), isTrue,
            reason: '${c.id} has an unusable code "${c.code}"');
      }
    });
  });
}
