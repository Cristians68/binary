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

  const CourseInfo({
    required this.id,
    required this.tag,
    required this.title,
    required this.blurb,
    this.preparesFor,
  });
}

const List<CourseInfo> kCourseCatalog = [
  CourseInfo(
    id: 'itil-v4',
    tag: 'ITIL V4',
    title: 'IT Service Management Foundations',
    blurb:
        'How service organisations create value — service value systems, the '
        'four dimensions, guiding principles, and core practices.',
    preparesFor:
        'Covers the body of knowledge assessed by ITIL® 4 Foundation. '
        'ITIL® is a registered trademark of PeopleCert/AXELOS Limited. '
        'This course is independent and is not accredited, affiliated with, '
        'or endorsed by them.',
  ),
  CourseInfo(
    id: 'csm',
    tag: 'CSM',
    title: 'Agile & Scrum Foundations',
    blurb:
        'Agile delivery in practice — the Scrum framework, accountabilities, '
        'events, artifacts, and how teams scale it.',
    preparesFor:
        'Covers the body of knowledge assessed by entry-level Scrum '
        'certifications. Certified ScrumMaster® and CSM® are registered '
        'trademarks of Scrum Alliance, Inc. This course is independent and is '
        'not accredited, affiliated with, or endorsed by them.',
  ),
  CourseInfo(
    id: 'binary-network-pro',
    tag: 'Binary Network Pro',
    title: 'Network Professional',
    blurb:
        'Networking end to end — OSI and TCP/IP, subnetting, routing and '
        'switching, wireless, DNS/DHCP, and troubleshooting.',
    preparesFor:
        'Covers foundational networking concepts also assessed by vendor-'
        'neutral networking certifications. CompTIA® and Network+® are '
        'registered trademarks of CompTIA, Inc. This course is independent '
        'and is not accredited, affiliated with, or endorsed by them.',
  ),
  CourseInfo(
    id: 'binary-cyber-pro',
    tag: 'Binary Cyber Pro',
    title: 'Cybersecurity Professional',
    blurb:
        'Defensive security fundamentals — threats, cryptography, access '
        'control, network hardening, and incident response.',
    preparesFor:
        'Covers foundational security concepts also assessed by vendor-'
        'neutral security certifications. CompTIA® and Security+® are '
        'registered trademarks of CompTIA, Inc. This course is independent '
        'and is not accredited, affiliated with, or endorsed by them.',
  ),
  CourseInfo(
    id: 'binary-cloud',
    tag: 'Binary Cloud',
    title: 'Cloud Fundamentals',
    blurb:
        'Cloud computing from first principles — service and deployment '
        'models, virtualisation, storage, and cost.',
  ),
  CourseInfo(
    id: 'binary-cloud-pro',
    tag: 'Binary Cloud Pro',
    title: 'Cloud Architecture',
    blurb:
        'Designing for the cloud — availability, scaling, networking, '
        'identity, and well-architected trade-offs.',
  ),
];

final Map<String, CourseInfo> _byId = {
  for (final c in kCourseCatalog) c.id: c,
};

final Map<String, CourseInfo> _byTag = {
  for (final c in kCourseCatalog) c.tag: c,
};

/// Look up by Firestore id, falling back to tag.
CourseInfo? courseInfo(String idOrTag) =>
    _byId[idOrTag] ?? _byTag[idOrTag];

/// Trademark-safe title for any course id or internal tag.
///
/// Falls back to the input so a newly seeded course that isn't in the
/// catalogue yet still renders something sensible rather than blank.
String displayTitle(String idOrTag) =>
    courseInfo(idOrTag)?.title ?? idOrTag;

/// Short description for cards and paywall rows.
String displayBlurb(String idOrTag) => courseInfo(idOrTag)?.blurb ?? '';

/// Nominative "what this maps to" text, including the trademark notice.
/// Returns null when the course maps to no external certification.
String? preparesFor(String idOrTag) => courseInfo(idOrTag)?.preparesFor;

/// Global attribution shown on the legal screen and in the App Store listing.
const String kTrademarkNotice =
    'Binary Academy is an independent educational app. It is not accredited '
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
