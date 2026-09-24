const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

// Load account.js against stubs: the real modules need a live project.
function stub(id, exports) {
  const file = require.resolve(id, { paths: [path.join(__dirname, "..")] });
  require.cache[file] = { id: file, filename: file, loaded: true, exports };
}

test("deleteAccount removes the whole user tree, then the Auth record", async () => {
  const calls = [];
  const userRef = { path: "users/u1" };
  stub("firebase-functions/v2/https", {
    onCall: (handler) => handler,
    HttpsError: class extends Error {},
  });
  stub("firebase-admin", {
    firestore: () => ({
      collection: () => ({
        doc: (id) => {
          assert.equal(id, "u1");
          return userRef;
        },
      }),
      recursiveDelete: async (ref) => calls.push(["recursiveDelete", ref.path]),
    }),
    auth: () => ({ deleteUser: async (uid) => calls.push(["deleteUser", uid]) }),
  });
  delete require.cache[require.resolve("../account.js")];
  const { deleteAccount } = require("../account.js");

  assert.deepEqual(await deleteAccount({ auth: { uid: "u1" } }), { ok: true });
  // recursiveDelete reaches progress, quiz attempt receipts and the profile
  // photo alike; the Auth record goes last so a failure can be retried.
  assert.deepEqual(calls, [
    ["recursiveDelete", "users/u1"],
    ["deleteUser", "u1"],
  ]);
});
