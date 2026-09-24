/**
 * Make the four 20-module courses playable.
 *
 * THE PROBLEM (found 2026-09-23 from a tester's screen recording)
 *
 * binary-network-professional, binary-cybersecurity-professional,
 * binary-cloud-fundamentals and binary-cloud-professional were seeded by a
 * different tool than every other course:
 *   - no `flashcards` subcollection at all;
 *   - the quiz lives in `quizQuestions`, and those docs carry no `order`;
 *   - the lesson text is terse markdown (now at body/lesson).
 * The app (lib/screens/content_service.dart) reads only `flashcards` and
 * `quiz`, ordered by `order`, so every module — including the free Module 1 —
 * opened on "Let's try that again". 80 of the catalogue's modules.
 *
 * THE FIX
 *
 * 1. Flashcards: 6 original cards per module, written from each module's
 *    outline, loaded from admin/private/flashcards/<courseId>.json. That folder
 *    is gitignored on purpose: the repo is public and these are paid courses.
 * 2. Quiz: each module's quizQuestions docs are copied to `quiz/q-N` with
 *    `order: N`. quizQuestions is left in place, untouched.
 *
 * SAFETY
 *   - Dry run is the default. Nothing is written without --commit.
 *   - Everything is validated against the app's own parser rules
 *     (lib/course_content.dart) before any write; one bad card would make the
 *     app reject the whole module, so a single failure aborts the run.
 *   - A module that already has flashcards, or already has a quiz, is skipped
 *     for that part, so re-running is a no-op.
 *
 * RUN
 *   GOOGLE_CLOUD_PROJECT=binary-6a372 NODE_PATH=functions/node_modules \
 *     node admin/migrate/2026-09-23-restore-pro-course-content.js [--commit]
 */

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();
const COMMIT = process.argv.includes("--commit");
const COURSES = [
  "binary-network-professional",
  "binary-cybersecurity-professional",
  "binary-cloud-fundamentals",
  "binary-cloud-professional",
];
const CARDS_DIR = path.join(__dirname, "..", "private", "flashcards");

// Mirrors parseFlashcards / parseQuizQuestions in lib/course_content.dart.
function cardProblem(c) {
  if (typeof c.question !== "string" || !c.question.trim()) return "empty question";
  if (typeof c.answer !== "string" || !c.answer.trim()) return "empty answer";
  if (c.example !== undefined && typeof c.example !== "string") return "example not a string";
  return null;
}
function quizProblem(q) {
  const o = q.options;
  if (typeof q.question !== "string" || !q.question.trim()) return "empty question";
  if (!Array.isArray(o) || o.length < 2) return "fewer than 2 options";
  if (o.some((x) => typeof x !== "string" || !x.trim())) return "blank option";
  if (!Number.isInteger(q.correctIndex) || q.correctIndex < 0 || q.correctIndex >= o.length) return "bad correctIndex";
  if (new Set(o.map((x) => x.trim())).size !== o.length) return "duplicate options";
  return null;
}

(async () => {
  console.log(`mode: ${COMMIT ? "COMMIT - documents WILL be written" : "dry run - nothing is written"}\n`);
  const plan = [];
  const problems = [];

  for (const courseId of COURSES) {
    const file = path.join(CARDS_DIR, `${courseId}.json`);
    if (!fs.existsSync(file)) { problems.push(`${courseId}: missing ${file}`); continue; }
    const cards = JSON.parse(fs.readFileSync(file, "utf8"));
    const mods = await db.collection(`courses/${courseId}/modules`).get();
    const liveIds = new Set(mods.docs.map((d) => d.id));
    for (const id of Object.keys(cards)) if (!liveIds.has(id)) problems.push(`${courseId}: cards for unknown module ${id}`);

    for (const m of mods.docs) {
      const mine = cards[m.id];
      if (!Array.isArray(mine) || mine.length === 0) { problems.push(`${courseId}/${m.id}: no cards written`); continue; }
      mine.forEach((c, i) => { const p = cardProblem(c); if (p) problems.push(`${courseId}/${m.id} card ${i + 1}: ${p}`); });

      const [flash, quiz, legacy] = await Promise.all([
        m.ref.collection("flashcards").limit(1).get(),
        m.ref.collection("quiz").limit(1).get(),
        m.ref.collection("quizQuestions").get(),
      ]);
      const legacyQs = legacy.docs.map((d) => d.data());
      legacyQs.forEach((q, i) => { const p = quizProblem(q); if (p) problems.push(`${courseId}/${m.id} quiz ${i + 1}: ${p}`); });
      if (quiz.empty && legacyQs.length === 0) problems.push(`${courseId}/${m.id}: no quiz anywhere`);

      plan.push({ ref: m.ref, where: `${courseId}/${m.id}`, cards: flash.empty ? mine : null, quiz: quiz.empty ? legacyQs : null });
    }
  }

  if (problems.length) {
    console.log("VALIDATION FAILED - nothing written:");
    problems.forEach((p) => console.log("  " + p));
    process.exit(1);
  }

  let cardsN = 0, quizN = 0, skippedCards = 0, skippedQuiz = 0;
  for (const p of plan) {
    const batch = db.batch();
    if (p.cards) {
      p.cards.forEach((c, i) => batch.set(p.ref.collection("flashcards").doc(`card-${i + 1}`), { ...c, order: i + 1 }));
      cardsN += p.cards.length;
    } else skippedCards++;
    if (p.quiz) {
      p.quiz.forEach((q, i) => batch.set(p.ref.collection("quiz").doc(`q-${i + 1}`), { ...q, order: i + 1 }));
      quizN += p.quiz.length;
    } else skippedQuiz++;
    if (COMMIT && (p.cards || p.quiz)) await batch.commit();
  }

  console.log(`modules checked            : ${plan.length}`);
  console.log(`flashcards ${COMMIT ? "written" : "to write"}         : ${cardsN}  (modules already carded: ${skippedCards})`);
  console.log(`quiz questions ${COMMIT ? "written" : "to write"}     : ${quizN}  (modules already quizzed: ${skippedQuiz})`);
  if (!COMMIT) console.log("\nNothing was written. Re-run with --commit to apply.");
})().catch((e) => { console.error("ERR", e.message); process.exit(1); });
