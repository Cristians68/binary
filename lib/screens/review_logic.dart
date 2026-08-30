/// Spaced-repetition scheduling for questions the user got wrong.
///
/// WHY THIS IS SEPARATE FROM [ReviewService]
/// -----------------------------------------
/// Everything here is a pure function over plain maps. No Firestore, no
/// SharedPreferences, no widgets. That is deliberate: the scheduling rules
/// decide what the user is asked and when, and a silent bug here means either
/// questions that never come back or a review queue that never drains. Pure
/// functions make the whole algorithm testable without a plugin or a fake, and
/// `test/review_logic_test.dart` exercises it directly.
///
/// THE MODEL
/// ---------
/// A Leitner box system. A missed question enters at box 0 and is due
/// immediately. Answer it correctly in review and it moves up a box, with a
/// longer wait before it returns. Miss it again and it drops straight back to
/// box 0 — not down one box — because a question you have just failed is one
/// you do not know, whatever your history with it.
///
/// Clearing the last box retires the question and removes it from the queue.
library;

/// How long a question waits before it comes back, indexed by box.
///
/// Box 0 is due immediately so a missed question is reviewed in the same
/// sitting while the explanation is still fresh. The rest roughly triple, which
/// is the usual expanding-interval shape.
const List<Duration> kReviewIntervals = [
  Duration.zero,
  Duration(days: 1),
  Duration(days: 3),
  Duration(days: 7),
  Duration(days: 21),
];

/// A question that has cleared every box is considered learned and leaves the
/// queue. Equal to `kReviewIntervals.length`.
const int kRetiredBox = 5;

/// Stable identity for a question.
///
/// Quiz documents are keyed by position (`q-1`, `q-2`), and reordering or
/// reseeding a module would shuffle those ids onto different questions. Keying
/// on the question text instead means a question keeps its review history as
/// long as its wording is unchanged, and a genuinely reworded question
/// correctly starts over.
String reviewItemId(String courseId, String moduleId, String question) =>
    '$courseId|$moduleId|${question.trim()}';

/// The box a question moves to after a review attempt.
///
/// A wrong answer always returns to 0. Anything else lets a question the user
/// keeps failing drift upward and disappear from review, which is exactly
/// backwards.
int nextReviewBox(int box, {required bool correct}) {
  if (!correct) return 0;
  final next = box + 1;
  return next > kRetiredBox ? kRetiredBox : next;
}

/// When a question in [box] should next be shown.
DateTime dueAtForBox(int box, DateTime from) {
  if (box < 0) return from;
  if (box >= kReviewIntervals.length) {
    // Retired items are not scheduled; return a far-future date so a stray one
    // can never be picked up as due.
    return from.add(const Duration(days: 3650));
  }
  return from.add(kReviewIntervals[box]);
}

/// Whether [item] is ready to be shown at [now].
bool isReviewDue(Map<String, dynamic> item, DateTime now) {
  final box = item['box'];
  if (box is! int || box >= kRetiredBox) return false;
  final dueAt = item['dueAt'];
  if (dueAt is! int) return true; // Missing schedule: show it rather than lose it.
  return !DateTime.fromMillisecondsSinceEpoch(dueAt).isAfter(now);
}

/// Every due item, soonest-due first, then most-missed first.
///
/// The secondary sort puts the questions the user keeps failing at the front of
/// a session, where attention is highest.
List<Map<String, dynamic>> dueReviewItems(
  List<Map<String, dynamic>> items,
  DateTime now,
) {
  final due = items.where((i) => isReviewDue(i, now)).toList();
  due.sort((a, b) {
    final ad = (a['dueAt'] as int?) ?? 0;
    final bd = (b['dueAt'] as int?) ?? 0;
    if (ad != bd) return ad.compareTo(bd);
    final am = (a['misses'] as int?) ?? 0;
    final bm = (b['misses'] as int?) ?? 0;
    return bm.compareTo(am);
  });
  return due;
}

/// Records that a question was answered wrong, returning a new queue.
///
/// A question already in the queue is not duplicated: its miss count rises and
/// it drops back to box 0, due immediately. [question] carries the full text,
/// options and explanation so a review session never has to re-fetch anything
/// and works with no connection.
List<Map<String, dynamic>> recordMissedQuestion(
  List<Map<String, dynamic>> items, {
  required String courseId,
  required String moduleId,
  required String courseTag,
  required Map<String, dynamic> question,
  required DateTime now,
}) {
  final text = (question['question'] ?? '').toString();
  if (text.trim().isEmpty) return items; // Nothing identifiable to schedule.

  final id = reviewItemId(courseId, moduleId, text);
  final out = <Map<String, dynamic>>[];
  var found = false;

  for (final item in items) {
    if (item['id'] != id) {
      out.add(item);
      continue;
    }
    found = true;
    out.add({
      ...item,
      // Refresh the stored copy: the module's wording may have been reseeded.
      'answers': List<String>.from(question['answers'] as List? ?? const []),
      'correct': question['correct'],
      'explanation': (question['explanation'] ?? '').toString(),
      'box': 0,
      'dueAt': now.millisecondsSinceEpoch,
      'misses': ((item['misses'] as int?) ?? 0) + 1,
    });
  }

  if (!found) {
    out.add({
      'id': id,
      'courseId': courseId,
      'moduleId': moduleId,
      'courseTag': courseTag,
      'question': text,
      'answers': List<String>.from(question['answers'] as List? ?? const []),
      'correct': question['correct'],
      'explanation': (question['explanation'] ?? '').toString(),
      'box': 0,
      'dueAt': now.millisecondsSinceEpoch,
      'misses': 1,
      'addedAt': now.millisecondsSinceEpoch,
    });
  }
  return out;
}

/// Applies the outcome of one review attempt, returning a new queue.
///
/// A question that clears the final box is dropped rather than kept at
/// [kRetiredBox], so the stored queue does not grow without bound over months
/// of use.
List<Map<String, dynamic>> applyReviewResult(
  List<Map<String, dynamic>> items, {
  required String id,
  required bool correct,
  required DateTime now,
}) {
  final out = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item['id'] != id) {
      out.add(item);
      continue;
    }
    final box = nextReviewBox((item['box'] as int?) ?? 0, correct: correct);
    if (box >= kRetiredBox) continue; // Learned — remove from the queue.
    out.add({
      ...item,
      'box': box,
      'dueAt': dueAtForBox(box, now).millisecondsSinceEpoch,
      'lastSeenAt': now.millisecondsSinceEpoch,
      if (!correct) 'misses': ((item['misses'] as int?) ?? 0) + 1,
    });
  }
  return out;
}

/// Human-readable summary of when the queue next has something to offer.
/// Returns null when the queue is empty.
String? nextReviewDueLabel(List<Map<String, dynamic>> items, DateTime now) {
  final scheduled = items
      .where((i) => ((i['box'] as int?) ?? 0) < kRetiredBox)
      .map((i) => (i['dueAt'] as int?) ?? 0)
      .toList()
    ..sort();
  if (scheduled.isEmpty) return null;

  final soonest = DateTime.fromMillisecondsSinceEpoch(scheduled.first);
  if (!soonest.isAfter(now)) return 'Ready now';

  final gap = soonest.difference(now);
  if (gap.inHours < 1) return 'Ready in ${gap.inMinutes + 1} min';
  if (gap.inHours < 24) return 'Ready in ${gap.inHours} h';
  final days = gap.inDays;
  return days <= 1 ? 'Ready tomorrow' : 'Ready in $days days';
}
