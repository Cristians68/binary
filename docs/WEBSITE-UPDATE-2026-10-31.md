# Website update — October 31, 2026

Updated and deployed the existing Firebase Hosting site at
`https://binaryapp.org` and `https://binary-6a372.web.app`. The browser app
under `/app/` was rebuilt with Flutter 3.47.2 and RevenueCat Flutter 10.19.0.

## Current public content

- A dedicated seven-day trial section explains the actual menu path, one
  chosen course per account, fixed expiry, preserved progress, and no card,
  renewal or automatic payment.
- Course names match all seven entries in `lib/course_catalog.dart`. Feature
  copy covers active recall, explained quizzes, focused mistake practice,
  spaced review, search, adaptive layouts, certificates and private feedback.
- Offline copy distinguishes downloaded flashcards/recall from quizzes and
  access updates that require a connection. Downloads do not extend a trial.
- Paid plans use the app's labels: Single course, Any 4 Courses, Everything.
  The pages disclose that iOS and paid checkout are in preparation. Removed
  unverified fixed prices and purchasable paid offers from structured data.
- Support reflects the current profile menus, guest-account linking, restore
  limitations, original bundle selections, feedback, downloads and certificates.
- Privacy describes trial records, private feedback and its version metadata,
  local browser storage, and feedback stored separately from course progress.
  Terms describe the actual trial. Accessibility distinguishes tested behavior
  from unverified native assistive-technology flows.
- Updated browser/PWA metadata, brand colors, social descriptions and sitemap
  modification dates. The unversioned stylesheet now revalidates on page loads.

## Verification

- Release web build succeeds, including the Wasm dry run.
- Website checks pass in light/dark at 1280px, 390px and 320px with doubled
  text: layout, shared palette contrast, anchors, seven courses and keyboard
  recall. Recall works with JavaScript disabled; all five public pages load.
- Visual review caught a header/hero text-clipping issue at doubled text size.
  Fixed header wrapping and word reflow; extended the existing checker to
  inspect header bounds and text ranges, beyond ordinary element box bounds.
- Internal audit passes for 101 links/assets, section anchors, metadata JSON,
  unique page IDs, one main heading per page and all seven course titles.
- All seven existing app-link tests pass. JavaScript syntax and Git whitespace
  checks pass.
- Firebase Hosting deployment completed. At `2026-10-31T16:04:34Z`, 22 live
  checks across both domains returned HTTP 200 and matched local SHA-256 hashes:
  five public pages, CSS, sitemap, app HTML, manifest, main JavaScript and
  Flutter bootstrap. The live CSS cache header requires revalidation.

Local evidence remains ignored under `.dart_tool/site-review/` and `build/`.
This website update does not configure RevenueCat secrets/webhooks, deploy
purchase functions, start Codemagic, or establish native purchase readiness.
