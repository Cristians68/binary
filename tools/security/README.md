# Security probes

## Local release gate

From the repository root, with Node 22+ and Java 21 available:

```sh
npm --prefix tools/security ci
npm --prefix tools/security test
```

On this Windows machine, Android Studio includes Java 21. For the current shell:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm --prefix tools/security test
```

The first run downloads Firebase's emulator JAR. No Firebase login or billing is
needed. The separate root `firebase.emulator.json` starts only Firestore on
127.0.0.1:8086; the runner fixes the project to `demo-binary-release` and the test
file refuses a missing or non-loopback emulator host. All accounts and course
content are synthetic. Production data and configuration are untouched.

`firestore.rules.test.js` loads the real root rules and clears the demo database
between its 16 scenarios. Positive controls exercise real document and query
reads, so a broken fixture cannot masquerade as secure access denial. Coverage:

- Guest metadata and both preview module IDs; signed-out and unpaid denials.
- Multiple course purchases, bundles plus a single course, All Courses and trials.
- Refund/transfer revocation and denial of unresolved receipts/pending checkouts.
- Old forged profile lists, protected field writes/removals, private purchase data.
- Owner progress/attempts, private photo shape and byte limits, admin-only content.

Both Codemagic workflows run this gate before an iOS archive can be produced.
The local suite complements the deployed-rule probe below; it cannot establish
which rules are live or verify StoreKit and RevenueCat configuration.

Dependencies are locked and used only by the test tooling. The gRPC override
selects the patched 1.x client because Firebase's own constraint selects an older
version. After compatible fixes on 2026-10-05, npm still reports 11 transitive
CLI advisories (7 high, 4 moderate, involving braces, proxy/FTP handling,
OpenTelemetry and uuid). These are not part of the Flutter or Functions package.
Do not use `npm audit fix --force` to downgrade Firebase or the CLI; review
upstream updates and rerun this suite when adjusting the lockfile.

Reference: [Firebase rules testing](https://firebase.google.com/docs/rules/unit-tests)
and [the Firestore emulator](https://firebase.google.com/docs/emulator-suite/connect_firestore).

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
