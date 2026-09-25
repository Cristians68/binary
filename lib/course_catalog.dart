/// Canonical course catalogue and trademark-safe display names.
///
/// WHY THIS EXISTS
/// ---------------
/// Course titles used to be string literals scattered across a dozen screens,
/// and several of them were registered trademarks used as product names:
/// "ITIL V4 Foundation" (PeopleCert/AXELOS), "CSM Fundamentals" (Scrum
/// Alliance), "CompTIA Network+" (CompTIA). Using a certification mark as the
/// name of a paid product implies an affiliation we do not have, which is both
/// a trademark problem and an App Store Review Guideline 5.2.1 problem.
///
/// The fix is to sell a *skill*, not a *certification brand*:
///   - [displayTitle] returns the neutral, ownable product name.
///   - [preparesFor] returns an optional factual, nominative reference
///     ("Covers concepts assessed by ...") for places where telling the user
///     what the course is useful for is genuinely informative.
///
/// The internal ids and tags are DELIBERATELY unchanged. They are matched
/// against the `tag` field on Firestore course documents and against switch
/// statements in the lesson/quiz screens; renaming them would orphan live user
/// progress. Only what the user READS changes.
library;

class CourseInfo {
  /// Firestore document id under `courses/`.
  final String id;

  /// Internal tag, matched by switch statements and Firestore `tag`.
  /// Never shown to the user directly — pass it through [displayTitle].
  final String tag;

  /// Trademark-safe product name shown in the UI.
  final String title;

  /// One-line description for cards and the paywall.
  final String blurb;

  /// Factual, nominative statement of what the material maps to.
  /// Null where the course maps to no specific external exam.
  final String? preparesFor;

  /// Short, stable code used inside a completion credential ID.
  ///
  /// It appears on the certificate a learner shares publicly, so it has to be
  /// readable and it has to never change: a credential that changes is not a
  /// credential. Like [id] and [tag], this is NOT to be renamed once shipped —
  /// doing so invalidates every certificate already issued for the course.
  final String code;

  /// One non-consumable per course, aligned with functions/purchase_catalog.js.
  String get productId => 'binary_course_${code.toLowerCase()}';

  const CourseInfo({
    required this.id,
    required this.tag,
    required this.title,
    required this.blurb,
    required this.code,
    this.preparesFor,
  });
}

const List<CourseInfo> kCourseCatalog = [
  CourseInfo(
    id: 'itil-v4',
    code: 'ITSM',
    tag: 'ITIL V4',
    title: 'IT Service Management Foundations',
    blurb:
        'How service organisations create value — service value systems, the '
        'four dimensions, guiding principles, and core practices.',
    preparesFor: 'Covers the body of knowledge assessed by ITIL® 4 Foundation. '
        'ITIL® is a registered trademark of PeopleCert/AXELOS Limited. '
        'This course is independent and is not accredited, affiliated with, '
        'or endorsed by them.',
  ),
  CourseInfo(
    id: 'csm',
    code: 'SCRM',
    tag: 'CSM',
    title: 'Agile & Scrum Foundations',
    blurb:
        'Agile delivery in practice — the Scrum framework, accountabilities, '
        'events, artifacts, and how teams scale it.',
    preparesFor: 'Covers the body of knowledge assessed by entry-level Scrum '
        'certifications. Certified ScrumMaster® and CSM® are registered '
        'trademarks of Scrum Alliance, Inc. This course is independent and is '
        'not accredited, affiliated with, or endorsed by them.',
  ),
  CourseInfo(
    id: 'binary-network-professional',
    code: 'NETP',
    tag: 'Binary Network Pro',
    title: 'Network Professional',
    blurb: 'Networking end to end — OSI and TCP/IP, subnetting, routing and '
        'switching, wireless, DNS/DHCP, and troubleshooting.',
    preparesFor:
        'Covers foundational networking concepts also assessed by vendor-'
        'neutral networking certifications. CompTIA® and Network+® are '
        'registered trademarks of CompTIA, Inc. This course is independent '
        'and is not accredited, affiliated with, or endorsed by them.',
  ),
  CourseInfo(
    id: 'binary-cybersecurity-professional',
    code: 'SECP',
    tag: 'Binary Cyber Pro',
    title: 'Cybersecurity Professional',
    blurb: 'Defensive security fundamentals — threats, cryptography, access '
        'control, network hardening, and incident response.',
    preparesFor:
        'Covers foundational security concepts also assessed by vendor-'
        'neutral security certifications. CompTIA® and Security+® are '
        'registered trademarks of CompTIA, Inc. This course is independent '
        'and is not accredited, affiliated with, or endorsed by them.',
  ),
  CourseInfo(
    id: 'binary-cloud-fundamentals',
    code: 'CLDF',
    tag: 'Binary Cloud',
    title: 'Cloud Fundamentals',
    blurb: 'Cloud computing from first principles — service and deployment '
        'models, virtualisation, storage, and cost.',
  ),
  CourseInfo(
    id: 'binary-cloud-professional',
    code: 'CLDA',
    tag: 'Binary Cloud Pro',
    title: 'Cloud Architecture',
    blurb: 'Designing for the cloud — availability, scaling, networking, '
        'identity, and well-architected trade-offs.',
  ),
  // Deliberately has no `preparesFor`. The AI certification landscape is
  // young and vendor-specific, and claiming alignment with somebody's exam
  // would mean describing a syllabus we have no licence to. The content is
  // original explanation of publicly established concepts and maps to no
  // external exam, so it claims none.
  CourseInfo(
    id: 'binary-ai-fundamentals',
    code: 'AIML',
    tag: 'Binary AI',
    title: 'AI & Machine Learning Foundations',
    blurb: 'How modern AI actually works — machine learning, neural networks, '
        'language models, prompting, model quality, and responsible use.',
  ),
];

final Map<String, CourseInfo> _byId = {
  for (final c in kCourseCatalog) c.id: c,
};

final Map<String, CourseInfo> _byTag = {
  for (final c in kCourseCatalog) c.tag: c,
};

/// Look up by Firestore id, falling back to tag.
CourseInfo? courseInfo(String idOrTag) => _byId[idOrTag] ?? _byTag[idOrTag];

/// Trademark-safe title for any course id or internal tag.
///
/// Falls back to the input so a newly seeded course that isn't in the
/// catalogue yet still renders something sensible rather than blank.
String displayTitle(String idOrTag) => courseInfo(idOrTag)?.title ?? idOrTag;

/// The subset of Firestore course documents that the app is allowed to show.
///
/// The catalogue is an ALLOW-LIST, not a lookup table with a fallback. Every
/// other helper here degrades gracefully — [displayTitle] returns its input so
/// a newly seeded course still renders something. That fallback is exactly the
/// hole: an uncatalogued course displays whatever title sits in Firestore, and
/// the catalogue's whole job is to stop a certification mark being used as a
/// product name (Guideline 5.2.1). `courses/networking` is a live example — a
/// legacy document that rendered as a lowercase "networking" card.
///
/// So a course nobody has given a trademark-safe name is not shown at all.
/// The cost is deliberate: seeding a new course now requires adding it here
/// too, which is the point — naming it is part of shipping it.
List<Map<String, dynamic>> knownCourses(List<Map<String, dynamic>> docs) {
  return docs.where((d) {
    final id = d['id'];
    return id is String && courseInfo(id) != null;
  }).toList();
}

/// Short description for cards and paywall rows.
String displayBlurb(String idOrTag) => courseInfo(idOrTag)?.blurb ?? '';

/// Nominative "what this maps to" text, including the trademark notice.
/// Returns null when the course maps to no external certification.
String? preparesFor(String idOrTag) => courseInfo(idOrTag)?.preparesFor;

/// Global attribution shown on the legal screen and in the App Store listing.
const String kTrademarkNotice =
    'B1nary is an independent educational app. It is not accredited '
    'by, affiliated with, endorsed by, or sponsored by any certification '
    'body. All product names, logos, and brands are property of their '
    'respective owners and are used for identification purposes only.\n\n'
    'ITIL® is a registered trademark of PeopleCert/AXELOS Limited.\n'
    'Certified ScrumMaster® and CSM® are registered trademarks of Scrum '
    'Alliance, Inc.\n'
    'CompTIA®, Network+® and Security+® are registered trademarks of '
    'CompTIA, Inc.\n'
    'AWS® is a registered trademark of Amazon Web Services, Inc.\n'
    'Azure® is a registered trademark of Microsoft Corporation.\n'
    'Google Cloud® is a registered trademark of Google LLC.';

/// Trademark-safe replacements for module titles stored in Firestore.
///
/// The course-level scrub renamed the *products* ('itil-v4' displays as "IT
/// Service Management Foundations") but it never reached the module titles,
/// which live in `courses/{id}/modules` and were seeded before it. Three of
/// them still used a certification mark as the title of paid content:
/// "Introduction to ITIL V4", "ITIL Practices Overview" and "CSM Exam Prep".
///
/// That is the same Guideline 5.2.1 problem the catalogue exists to avoid, and
/// it was visible on the course screen a reviewer opens first.
///
/// Mapped here rather than rewritten in Firestore on purpose. The stored title
/// is also the key written into each user's `completedLessons` history, so
/// changing it in the database would orphan every existing record; translating
/// at the point of display fixes new and historical rows alike.
///
/// Naming the framework *inside* a lesson stays as it is. You cannot teach
/// service management without saying "ITIL", and a factual reference in
/// educational content is nominative use — the thing that is not allowed is
/// using the mark to name the product.
const Map<String, String> _moduleTitleOverrides = {
  'introduction to itil v4': 'Introduction to Service Management',
  'itil practices overview': 'Core Service Management Practices',
  'csm exam prep': 'Scrum Master Exam Preparation',
};

/// The trademark-safe title for a module.
///
/// Falls through unchanged for the great majority of modules, which never
/// carried a mark ("The OSI Model", "Incident Response", "Scrum Events").
String displayModuleTitle(String? rawTitle) {
  final raw = (rawTitle ?? '').trim();
  if (raw.isEmpty) return raw;
  return _moduleTitleOverrides[raw.toLowerCase()] ?? raw;
}
