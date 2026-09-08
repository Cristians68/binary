/// Trademark safety for module titles.
///
/// The course-level scrub in `course_catalog.dart` renamed the products but
/// never reached the module titles, which are seeded into Firestore. Three of
/// them used a certification mark as the title of paid content — the exact
/// Guideline 5.2.1 problem the catalogue was written to avoid, sitting on the
/// first screen a reviewer opens.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:binary/course_catalog.dart';

void main() {
  group('displayModuleTitle', () {
    test('a mark used as a module title is replaced', () {
      expect(
        displayModuleTitle('Introduction to ITIL V4'),
        'Introduction to Service Management',
      );
      expect(
        displayModuleTitle('ITIL Practices Overview'),
        'Core Service Management Practices',
      );
      expect(
        displayModuleTitle('CSM Exam Prep'),
        'Scrum Master Exam Preparation',
      );
    });

    test('no replacement still contains the mark it replaced', () {
      for (final raw in [
        'Introduction to ITIL V4',
        'ITIL Practices Overview',
        'CSM Exam Prep',
      ]) {
        final shown = displayModuleTitle(raw);
        expect(shown.toUpperCase(), isNot(contains('ITIL')));
        expect(shown.toUpperCase(), isNot(contains('CSM')));
      }
    });

    test('titles that never carried a mark pass through untouched', () {
      for (final raw in [
        'The OSI Model',
        'Incident Response',
        'Scrum Events',
        'IP Addressing & Subnetting',
        'Final Exam Prep',
      ]) {
        expect(displayModuleTitle(raw), raw);
      }
    });

    test('matching ignores case and surrounding whitespace', () {
      // Firestore holds hand-seeded strings; the stored casing is not a
      // contract, and a title that drifts to "Introduction to ITIL v4" must
      // not silently start leaking the mark again.
      expect(
        displayModuleTitle('  introduction to itil v4  '),
        'Introduction to Service Management',
      );
      expect(
        displayModuleTitle('INTRODUCTION TO ITIL V4'),
        'Introduction to Service Management',
      );
    });

    test('null and empty are safe', () {
      expect(displayModuleTitle(null), '');
      expect(displayModuleTitle(''), '');
      expect(displayModuleTitle('   '), '');
    });
  });

  group('the course catalogue itself stays trademark-safe', () {
    test('no course is titled after a certification mark', () {
      const marks = [
        'ITIL',
        'CSM',
        'COMPTIA',
        'NETWORK+',
        'SECURITY+',
        'AWS',
        'AZURE',
        'CERTIFIED SCRUMMASTER',
      ];
      for (final course in kCourseCatalog) {
        for (final mark in marks) {
          expect(
            course.title.toUpperCase(),
            isNot(contains(mark)),
            reason: 'Course "${course.title}" uses the mark $mark as a '
                'product name, which is what Guideline 5.2.1 rejects.',
          );
        }
      }
    });

    test('every nominative reference carries its attribution', () {
      // preparesFor is where naming a certification is legitimate: it states
      // a fact about what the material covers. It must always be accompanied
      // by the ownership and non-affiliation statement.
      for (final course in kCourseCatalog) {
        final prep = course.preparesFor;
        if (prep == null) continue;
        expect(
          prep.contains('®'),
          isTrue,
          reason: '"${course.title}" names a mark without the ® symbol.',
        );
        expect(
          prep.toLowerCase(),
          anyOf(
            contains('registered trademark'),
            contains('trademark of'),
          ),
          reason: '"${course.title}" names a mark with no attribution.',
        );
      }
    });

    test('the global notice disclaims affiliation and names every owner', () {
      expect(kTrademarkNotice.toLowerCase(), contains('not accredited'));
      expect(kTrademarkNotice.toLowerCase(), contains('independent'));
      for (final owner in [
        'PeopleCert',
        'Scrum Alliance',
        'CompTIA',
        'Amazon Web Services',
        'Microsoft',
        'Google',
      ]) {
        expect(kTrademarkNotice, contains(owner));
      }
    });
  });
}
