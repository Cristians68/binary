/**
 * Close the lesson-prose leak found in the 2026-09-11 pre-submission audit.
 *
 * THE PROBLEM
 *
 * The seed scripts write the full lesson body into a `content` field ON the
 * module document:
 *
 *     courses/{courseId}/modules/{moduleId}   { title, subtitle, order,
 *                                               status, content: "# ..." }
 *
 * firestore.rules gates the module SUBCOLLECTIONS on entitlement, but the
 * module document itself is `allow read: if signedIn()` — it has to be, or the
 * course outline could not list locked modules. So the paid lesson text sits in
 * a field any signed-in user can read. Measured on 2026-09-11 with a throwaway
 * anonymous account holding no purchase: 20 of 20 modules of
 * binary-network-professional returned their full prose, 9,068 characters,
 * including "Final Exam Prep".
 *
 * Deploying the rules does NOT fix this. The gate is in the right place for
 * flashcards and quiz; the prose is simply not behind it.
 *
 * THE FIX
 *
 * Move the body into a subcollection, where the existing
 * `match /{content}/{docId}` entitlement gate already covers it, and remove the
 * field from the document:
 *
 *     courses/{courseId}/modules/{moduleId}/body/lesson   { content: "# ..." }
 *
 * Nothing in the app reads `content` today — verified by grep over lib/; the
 * lesson screen renders `flashcards` and the quiz renders `quiz`. So this
 * migration removes a leak and breaks no feature. The subcollection keeps the
 * text for whenever a lesson-prose view is built, and it will be gated from
 * day one.
 *
 * RUNNING IT
 *
 *   gcloud auth application-default login          # once, interactive
 *   cd admin/migrate
 *   GOOGLE_CLOUD_PROJECT=binary-6a372 \
 *     NODE_PATH=../../functions/node_modules \
 *     node 2026-09-11-seal-lesson-prose.js --dry-run
 *
 * --dry-run is the DEFAULT. Nothing is written unless you pass --commit.
 * Run the dry run first and read the report: it prints every document it would
 * touch and how many characters move.
 *
 * Re-running is safe. A module whose body has already moved is skipped, and the
 * copy is written before the field is cleared, so an interrupted run leaves the
 * text in at least one place and never in neither.
 *
 * AFTERWARDS
 *
 *   cd build/web && python -m http.server 8099 &
 *   cd tools/security && node run_probe.js
 *
 * and confirm the prose no longer comes back for a user with no entitlement.
 */

const admin = require("firebase-admin");

const COMMIT = process.argv.includes("--commit");
const PROJECT = process.env.GOOGLE_CLOUD_PROJECT || "binary-6a372";

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: PROJECT,
});

const db = admin.firestore();

async function main() {
  console.log(`project : ${PROJECT}`);
  console.log(`mode    : ${COMMIT ? "COMMIT — documents WILL be written" : "DRY RUN — nothing will be written"}`);
  console.log("");

  const courses = await db.collection("courses").get();
  if (courses.empty) {
    console.log("No courses found. Check the project id and your credentials.");
    return;
  }

  let moved = 0;
  let alreadyDone = 0;
  let empty = 0;
  let chars = 0;

  for (const course of courses.docs) {
    const modules = await course.ref.collection("modules").orderBy("order").get();
    if (modules.empty) continue;

    const touched = [];
    for (const mod of modules.docs) {
      const body = mod.get("content");

      if (typeof body !== "string" || body.trim() === "") {
        // Either never had prose, or a previous run already cleared it.
        const existing = await mod.ref.collection("body").doc("lesson").get();
        if (existing.exists) alreadyDone++;
        else empty++;
        continue;
      }

      chars += body.length;
      moved++;
      touched.push(`${mod.id} (${body.length} chars)`);

      if (COMMIT) {
        // Write the copy BEFORE clearing the original. If this run dies between
        // the two, the text still exists in the subcollection and the next run
        // finds the field and simply overwrites the same copy.
        await mod.ref.collection("body").doc("lesson").set(
          {
            content: body,
            movedAt: admin.firestore.FieldValue.serverTimestamp(),
            movedBy: "2026-09-11-seal-lesson-prose",
          },
          { merge: true },
        );
        await mod.ref.update({
          content: admin.firestore.FieldValue.delete(),
        });
      }
    }

    if (touched.length) {
      console.log(`${course.id}`);
      for (const t of touched) console.log(`   ${t}`);
    }
  }

  console.log("");
  console.log(`modules with prose to move : ${moved} (${chars} characters)`);
  console.log(`already migrated           : ${alreadyDone}`);
  console.log(`no prose on the document   : ${empty}`);

  if (!COMMIT && moved > 0) {
    console.log("");
    console.log("Nothing was written. Re-run with --commit to apply.");
  }
  if (COMMIT && moved > 0) {
    console.log("");
    console.log("Done. Now re-run tools/security/run_probe.js and confirm the");
    console.log("prose no longer returns for an account with no entitlement.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("MIGRATION FAILED:", e.message);
    console.error("Nothing further was written. Safe to re-run once fixed.");
    process.exit(1);
  });
