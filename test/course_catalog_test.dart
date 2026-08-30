import 'package:flutter_test/flutter_test.dart';
import 'package:binary/course_catalog.dart';

/// Certification marks that must never be used as a bare product name.
///
/// The catalogue exists because course titles used to BE these strings, which
/// implies an affiliation the app does not have - a trademark problem and an
/// App Store Review Guideline 5.2.1 problem. Referring to them factually
/// inside `preparesFor` is fine and deliberate; naming a product after one is
/// not.
const _marks = [
  'ITIL',
  'CSM',
  'Certified ScrumMaster',
  'CompTIA',
  'Network+',
  'Security+',
  'AWS',
  'Azure',
  'Google Cloud',
];

void main() {
  group('catalogue integrity', () {
    test('is not empty', () {
      expect(kCourseCatalog, isNotEmpty);
    });

    test('every id is unique', () {
      final ids = kCourseCatalog.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'a duplicate id would make courseInfo() ambiguous');
    });

    test('every internal tag is unique', () {
      final tags = kCourseCatalog.map((c) => c.tag).toList();
      expect(tags.toSet().length, tags.length);
    });

    test('no id collides with a different course tag', () {
      // courseInfo() falls back from id to tag. If one course's tag equalled
      // another's id, lookups would silently resolve to the wrong course.
      for (final c in kCourseCatalog) {
        for (final other in kCourseCatalog) {
          if (identical(c, other)) continue;
          expect(c.id, isNot(other.tag),
              reason: 'id "${c.id}" collides with the tag of "${other.id}"');
        }
      }
    });

    test('no course has an empty title or blurb', () {
      for (final c in kCourseCatalog) {
        expect(c.title.trim(), isNotEmpty, reason: c.id);
        expect(c.blurb.trim(), isNotEmpty, reason: c.id);
      }
    });
  });

  group('trademark safety', () {
    test('no course title contains a certification mark', () {
      for (final c in kCourseCatalog) {
        for (final mark in _marks) {
          expect(
            c.title.toLowerCase().contains(mark.toLowerCase()),
            isFalse,
            reason:
                'course "${c.id}" is titled "${c.title}", which uses the mark '
                '"$mark" as a product name',
          );
        }
      }
    });

    test('no blurb uses a certification mark as the product being sold', () {
      for (final c in kCourseCatalog) {
        for (final mark in _marks) {
          expect(
            c.blurb.toLowerCase().contains(mark.toLowerCase()),
            isFalse,
            reason: 'the blurb for "${c.id}" mentions "$mark"; a factual '
                'reference belongs in preparesFor, where the disclaimer is',
          );
        }
      }
    });

    test('any preparesFor naming a mark also disclaims affiliation', () {
      for (final c in kCourseCatalog) {
        final text = c.preparesFor;
        if (text == null) continue;
        final named =
            _marks.where((m) => text.toLowerCase().contains(m.toLowerCase()));
        if (named.isEmpty) continue;
        expect(text.toLowerCase(), contains('not accredited'),
            reason: '"${c.id}" names ${named.join(", ")} without a disclaimer');
        expect(text, contains('registered trademark'), reason: c.id);
      }
    });

    test('the global notice disclaims affiliation and lists the owners', () {
      expect(kTrademarkNotice, contains('independent'));
      expect(kTrademarkNotice.toLowerCase(), contains('not accredited'));
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

  group('lookup', () {
    test('resolves a course by its Firestore id', () {
      final c = courseInfo('itil-v4');
      expect(c, isNotNull);
      expect(c!.id, 'itil-v4');
    });

    test('resolves the same course by its internal tag', () {
      expect(courseInfo('ITIL V4')?.id, 'itil-v4');
      expect(courseInfo('Binary Cloud Pro')?.id, 'binary-cloud-professional');
    });

    test('every course is reachable by both its id and its tag', () {
      for (final c in kCourseCatalog) {
        expect(courseInfo(c.id)?.id, c.id);
        expect(courseInfo(c.tag)?.id, c.id);
      }
    });

    test('returns null for something not in the catalogue', () {
      expect(courseInfo('no-such-course'), isNull);
    });

    test('is case sensitive, matching Firestore document ids exactly', () {
      expect(courseInfo('ITIL-V4'), isNull);
    });
  });

  group('display helpers', () {
    test('displayTitle returns the trademark-safe product name', () {
      expect(displayTitle('itil-v4'), 'IT Service Management Foundations');
      expect(displayTitle('ITIL V4'), 'IT Service Management Foundations');
    });

    test('displayTitle falls back to the input for an unknown course', () {
      // A newly seeded course not yet in the catalogue should still render
      // something rather than a blank row.
      expect(displayTitle('binary-brand-new'), 'binary-brand-new');
    });

    test('displayBlurb returns empty for an unknown course', () {
      expect(displayBlurb('binary-brand-new'), '');
    });

    test('displayBlurb returns real text for every catalogued course', () {
      for (final c in kCourseCatalog) {
        expect(displayBlurb(c.id), isNotEmpty, reason: c.id);
      }
    });

    test('preparesFor is null where a course maps to no external exam', () {
      // The two cloud courses are deliberately generic.
      expect(preparesFor('binary-cloud-fundamentals'), isNull);
      expect(preparesFor('binary-cloud-professional'), isNull);
    });

    test('preparesFor is present for the certification-aligned courses', () {
      for (final id in [
        'itil-v4',
        'csm',
        'binary-network-professional',
        'binary-cybersecurity-professional',
      ]) {
        expect(preparesFor(id), isNotNull, reason: id);
      }
    });

    test('preparesFor is null for an unknown course', () {
      expect(preparesFor('binary-brand-new'), isNull);
    });
  });

  group('ids the rest of the app depends on', () {
    // These ids are matched against live Firestore documents and against
    // switch statements in the lesson and quiz screens. Renaming one orphans
    // real user progress, so pin them.
    test('the shipped course ids have not changed', () {
      expect(
        kCourseCatalog.map((c) => c.id).toSet(),
        {
          'itil-v4',
          'csm',
          'binary-network-professional',
          'binary-cybersecurity-professional',
          'binary-cloud-fundamentals',
          'binary-cloud-professional',
        },
      );
    });
  });
}
