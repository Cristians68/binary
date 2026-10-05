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
 * immediately before calling this. The server also checks the verified
 * token's auth_time: refreshing an old session alone is not reauthentication.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  const token = request.auth.token || {};
  const anonymous = token.firebase?.sign_in_provider === "anonymous";
  const now = Math.floor(Date.now() / 1000);
  // Anonymous accounts have no password/provider to reconfirm. Every other
  // account must have authenticated within five minutes, including callers
  // that bypass the app's confirmation screen entirely.
  if (!anonymous && (!Number.isFinite(token.auth_time) ||
      token.auth_time < now - 300 || token.auth_time > now + 60)) {
    throw new HttpsError("failed-precondition",
      "Sign in again before deleting your account.");
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
