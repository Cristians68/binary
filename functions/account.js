/**
 * Server-side account deletion.
 *
 * firestore.rules denies `allow delete` on /users/{uid} entirely — Firestore
 * document deletion must go through the Admin SDK, which bypasses rules.
 * Doing this from a Cloud Function (instead of client-side, as the old
 * delete_account_screen.dart did) also makes Firestore cleanup and the Auth
 * record deletion a single server-side operation: if the client deleted
 * Firestore data itself and then called `user.delete()`, a failure between
 * the two steps could delete the Auth account while leaving Firestore data
 * behind with no signed-in user left who could ever clean it up.
 *
 * The client must reauthenticate (re-enter password / Google sign-in)
 * immediately before calling this, same as before — this function trusts
 * `request.auth`, which Callable Functions populate from a verified, current
 * ID token.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  // Firestore does not cascade-delete subcollections. The old hand-written
  // walk knew only about progress/{courseId}/modules, so it left behind the
  // quiz attempt receipts under each module and the profile/photo doc.
  // recursiveDelete removes the document and every subcollection beneath it,
  // including any added later.
  await db.recursiveDelete(userRef);

  // Deleting the Auth record last: if anything above throws, the user can
  // still sign in and retry, rather than being locked out with orphaned data
  // and no account to sign in with to clean it up.
  await admin.auth().deleteUser(uid);

  return { ok: true };
});
