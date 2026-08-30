# Binary Academy — security model and deploy runbook

Last updated: 2026-07-26

## 1. The vulnerability this replaced

`SubscriptionService.canAccessCourse()` decided course access by reading
`users/{uid}.subscriptionPlan` out of Firestore. That document is the user's own,
and the client legitimately writes to it in six places (streak, FCM token,
enrolments, notification prefs, profile, signup). Any rule permissive enough to
allow those writes also allowed this:

```js
// From any signed-in client, with no special tooling:
firebase.firestore().collection('users').doc(myUid)
  .set({ subscriptionPlan: 'all' }, { merge: true });
```

That unlocked the entire paid catalogue. `hasUsedTrial` sat in the same document,
so trials were farmable by resetting it to `false`.

Separately, `canAccessCourse()` opened with `if (kIsWeb) return true;`, so every
paid course was free on the Firebase Hosting build at `binary-6a372.web.app`.

## 2. The model now

**RevenueCat is the source of truth. Firestore is a cache of it. The client is
never trusted.**

| Field | Written by | Client may write? |
|---|---|---|
| `subscriptionPlan` | `revenueCatWebhook` | No |
| `subscribedCourseId` | `revenueCatWebhook` | No |
| `bundleCourseIds` | `revenueCatWebhook` | No |
| `trialExpiry`, `trialCourseId`, `hasUsedTrial` | `startTrial` | No |
| `pendingCourseId`, `pendingBundleCourseIds` | `setPendingPurchase` | No (function only) |
| `streak`, `fcmToken`, `enrolments`, `notificationsEnabled`, profile | client | Yes |

Enforcement is in `firestore.rules` via `entitlementsUnchanged()`, which uses
`request.resource.data.diff(resource.data).affectedKeys()` so ordinary merge
writes that resend unchanged fields are not mistaken for tampering. The Admin SDK
bypasses rules entirely, which is how the webhook still writes them.

Content reads are gated too: `courses/{id}/modules/{mid}/{content}/{doc}` requires
a real entitlement, so a client cannot query around the in-app paywall. The first
module of every course stays readable as the free preview.

## 3. Deploy order — this matters

The rules and the code are a single change. Deploying rules first will break
purchases and trials for live users, because the current shipped client still
writes those fields directly.

```
1. Set the webhook secret (a long random string you generate):
   firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET

2. Deploy functions FIRST — the webhook must exist before rules block the client.
   firebase deploy --only functions

3. Configure RevenueCat:
   RevenueCat dashboard -> Integrations -> Webhooks
     URL:  https://<region>-binary-6a372.cloudfunctions.net/revenueCatWebhook
     Authorization header: the exact value from step 1
   Send a test event and confirm a 200 in the function logs.

4. Ship the app update and wait for adoption. Users on the OLD build will
   still work at this point, because rules are not yet tightened.

5. Only once adoption is acceptable, deploy rules:
   firebase deploy --only firestore:rules,firestore:indexes

6. Redeploy hosting to close the free-web-catalogue leak:
   flutter build web --release && firebase deploy --only hosting
```

Step 6 is independent of the rest and is the most urgent single item — the leak
is live until it runs.

## 4. Backfill

Existing users already have `subscriptionPlan` values written by the old client.
Some of those may be self-granted. Before step 5, reconcile against RevenueCat:

- Export RevenueCat's active-subscriber list.
- For any Firestore user whose plan is not `none` but who has no matching
  RevenueCat entitlement, the entitlement was not paid for.
- Decide deliberately whether to revoke or grandfather. Revoking will generate
  support tickets from anyone who exploited it; grandfathering rewards it.

## 5. Known remaining gaps

- **`refreshEntitlement` is deliberately unimplemented.** It throws `unimplemented`
  rather than shipping a stub that could silently grant access. Implementing it
  properly needs a RevenueCat *secret* API key (`sk_...`) stored as its own
  Firebase secret, then a server-side call to the RevenueCat REST API.
- **`admins/{uid}` is checked by the rules but no documents exist yet.** Create
  them by hand in the console for anyone who needs to write the catalogue.
  Nobody can self-enrol.
- **The RevenueCat public SDK key** (`appl_...`) is hardcoded in
  `subscription_service.dart`. This is **not** a vulnerability — that key class is
  designed to be embedded in clients and is safe to ship. It is only listed here
  so future audits do not re-flag it.

## 5a. Gaps that have since been closed

Listed so a reader does not treat them as outstanding, and does not redo them.

- **The in-client seeders are gone.** `lib/screens/seed_*.dart` no longer
  exists; content seeding moved to `admin/seed/` as Admin SDK scripts. Read
  `docs/CONTENT.md` before running any of them — they write to production and
  `create-network-pro.js` is quarantined.
- **Account deletion is server-side.** `functions/account.js` exports
  `deleteAccount`, and `delete_account_screen.dart` calls it rather than
  deleting from the client. The rules can keep `allow delete: if false`. This
  is no longer a blocker for step 5.

## 6. Verifying the fix

After step 5, from a signed-in client, this must fail with `permission-denied`:

```dart
await FirebaseFirestore.instance
    .collection('users').doc(FirebaseAuth.instance.currentUser!.uid)
    .set({'subscriptionPlan': 'all'}, SetOptions(merge: true));
```

While this must still succeed:

```dart
await FirebaseFirestore.instance
    .collection('users').doc(uid)
    .set({'notificationsEnabled': true}, SetOptions(merge: true));
```

Run both against the emulator (`firebase emulators:start`) before touching prod.
