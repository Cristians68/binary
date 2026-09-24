/// How many courses the Any-4 bundle covers.
const int kBundleSize = 4;

/// Ticks or unticks [courseId] in an Any-4 selection.
///
/// Every course can be unticked, including the one the paywall was opened
/// from. That one is only pre-ticked as a convenience; it used to be locked
/// in, so a learner arriving from one course could not buy a bundle without
/// it. A new tick is ignored once [kBundleSize] courses are chosen.
Set<String> toggleBundleCourse(Set<String> selection, String courseId) {
  final next = {...selection};
  if (!next.remove(courseId) && next.length < kBundleSize) {
    next.add(courseId);
  }
  return next;
}
