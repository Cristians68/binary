# App Store Connect submission status — 2026-10-19

App: B1nary Academy (`com.cristians.b1nary`, Apple ID `6762030524`). iOS version
`1.0.11` has TestFlight build `67` selected; Apple lists it as **Ready to Submit**.
Build 67 was uploaded October 18, 2026 at 1:02 PM and targets iPhone.

## Completed in App Store Connect

- Created seven non-consumable course products matching the app and backend IDs:
  `binary_course_itsm`, `binary_course_scrm`, `binary_course_netp`,
  `binary_course_secp`, `binary_course_cldf`, `binary_course_clda`, and
  `binary_course_aiml`.
- Set all-country availability, U.S. base price of $14.99 with Apple's comparable
  regional prices, English (U.S.) display names/descriptions, and reviewer
  navigation notes for each course product. Reopened product pages to confirm
  those fields persisted.
- Existing `binary_bundle_4`, `binary_bundle_all`, and restore-only
  `binary_course_single` remain drafts. The In-App Purchases page now shows ten
  drafts total. No purchase was submitted to App Review.
- Reviewed version metadata, selected build, App Privacy, and regional
  availability. App Privacy is published with `https://binaryapp.org/privacy`.

## Submission blockers

1. **Live checkout backend:** Read-only Firebase audit on October 19 confirms
   billing disabled, zero deployed Cloud Functions, disabled Secret Manager, and
   production Firestore rules that do not contain the current purchase snapshot
   authorization. The owner must enable Blaze billing; then follow
   [PURCHASES.md](PURCHASES.md) to configure RevenueCat secrets and offerings,
   deploy functions then rules, test the webhook and sandbox purchases/restores.
2. **IAP review screenshots:** Every product lacks its Review Information
   screenshot. App Store Connect rejected an `Add for Review` attempt on
   `binary_course_aiml` with “You must add a Review Information screenshot.”
   Capture the functional purchase screen from the shipping iPhone build after
   checkout works. The local preview paywall images show “Purchases are
   unavailable,” so they are unsuitable for review.
3. **Storefront screenshots:** Existing iPhone assets are inherited from an
   older Face ID display set. Six current 1320 × 2868 screenshots are prepared
   in `submission-assets/app-store/iphone-6.9/`, but their manifest records a
   Flutter web preview and no native-device verification. App Store Connect
   accepts this size for Dynamic Island large displays. Upload was blocked
   because the ChatGPT Chrome extension lacks “Allow access to file URLs.”
   Compare the images with build 67 on an iPhone before replacing the inherited
   assets.
4. **Regional availability:** 148 countries or regions are available; all 27
   EU member states are unavailable under the current non-trader DSA
   declaration. The owner should verify and update trader details if EU
   distribution is intended.
5. **Device checks:** Confirm guest entry, Apple/Google sign-in, a free first
   module, each purchase path, restore, refund, and account deletion on build
   67 before submitting. App Store Connect is configured for manual release
   after review approval.

Do not submit version 1.0.11 until checkout, restore, and account deletion are
working in production and the IAPs can be added to the review submission.
