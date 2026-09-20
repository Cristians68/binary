# Security probes

## `probe_rules.js` — does the deployed Firestore rule set actually hold?

Run this **after every `firebase deploy --only firestore:rules`**, and before
any App Store submission.

```
cd build/web && python -m http.server 8099 &
cd tools/security && node run_probe.js
```

It signs up throwaway anonymous accounts against the production project, tries
each abuse case, and deletes them again.

### Read the positive controls first

Every run prints `PC-*` cases that **must succeed** before any `AB-*` denial
means anything. A malformed request is refused with the same 403 as a
well-defended one, so a probe with no positive controls cannot tell a locked
database from a broken script. If a `PC-*` line says FAIL, fix the probe and
re-run; do not read the denials.

### What it is checking for

On 2026-09-11 `firestore.rules` was found never to have been deployed. The file
in this repository was correct; production was running an older, weaker set, and
any signed-in user could grant themselves every paid course with one request.
The Dart suite could not have caught it, because the file on disk was right.
