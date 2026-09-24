import 'package:binary/screens/bundle_selection.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Any-4 bundle picker pre-ticks the course the paywall was opened from,
/// and used to refuse to untick it: opened from Network Professional, a
/// learner could not buy any four courses that left Network Professional out.
void main() {
  test('the course the paywall was opened from can be unticked', () {
    final from = {'binary-network-professional'};
    expect(toggleBundleCourse(from, 'binary-network-professional'), isEmpty);
  });

  test('ticks up to four and no more', () {
    var s = <String>{};
    for (final id in ['a', 'b', 'c', 'd', 'e']) {
      s = toggleBundleCourse(s, id);
    }
    expect(s, {'a', 'b', 'c', 'd'});
  });

  test('unticking frees a slot for another course', () {
    var s = {'a', 'b', 'c', 'd'};
    s = toggleBundleCourse(s, 'b');
    s = toggleBundleCourse(s, 'e');
    expect(s, {'a', 'c', 'd', 'e'});
  });

  test('does not modify the set it was given', () {
    final s = {'a'};
    toggleBundleCourse(s, 'b');
    expect(s, {'a'});
  });
}
