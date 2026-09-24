/**
 * Reword course items that copied official wording, and fix a stale answer.
 *
 * A 2026-09-23 copyright scan of every flashcard, quiz item and lesson body
 * found sentences lifted word for word from:
 *   - the ITIL 4 Foundation glossary (copyright PeopleCert/AXELOS): the
 *     definitions of service, utility, warranty and outcome;
 *   - the Scrum Guide (CC BY-SA 4.0, reuse only with attribution under the
 *     same licence): the Sprint Goal and Daily Scrum sentences.
 * Naming a term or a framework is fine; reproducing its official definition
 * is not ours to publish. Each is rewritten in plain original words with the
 * meaning kept.
 *
 * Also: two items said AXELOS owns ITIL. PeopleCert acquired AXELOS in 2021,
 * so a learner was being marked right for an outdated answer.
 *
 * Every update is guarded: a doc is only touched if its field still contains
 * the flagged text, so re-running is a no-op and a hand edit is never
 * overwritten. The replacements also drop the broken "�" characters some
 * of these items carried.
 *
 * RUN (dry run is the default; nothing is written without --commit):
 *   GOOGLE_CLOUD_PROJECT=binary-6a372 NODE_PATH=functions/node_modules \
 *     node admin/migrate/2026-09-23-reword-official-definitions.js [--commit]
 */

const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();
const COMMIT = process.argv.includes("--commit");

const edits = [
  {
    path: "courses/itil-v4/modules/module-1/flashcards/HbrH6iKM85GtC1gHkMcv",
    guard: ["answer", "means of enabling value co-creation"],
    set: {
      answer: "Something that helps customers get the results they want, while the " +
        "provider takes on certain costs and risks for them. ITIL 4 stresses " +
        "that value is co-created: provider and customer create it together.",
    },
  },
  {
    path: "courses/itil-v4/modules/module-1/flashcards/card-4",
    guard: ["answer", "means of enabling value co-creation"],
    set: {
      answer: "A service helps customers reach results they care about while the " +
        "provider carries certain costs and risks on their behalf. ITIL 4 calls " +
        "this value co-creation: both sides create the value together, rather " +
        "than the provider simply handing it over.",
    },
  },
  {
    path: "courses/itil-v4/modules/module-2/flashcards/card-4",
    guard: ["answer", "the functionality offered by a product or service"],
    set: {
      answer: "Utility is what a product or service does: the features that meet a " +
        "need, often summed up as \"fit for purpose\". A service has utility when " +
        "it helps the consumer perform better or removes something holding them back.",
    },
  },
  {
    path: "courses/itil-v4/modules/module-2/flashcards/card-5",
    guard: ["answer", "assurance that a product or service will meet agreed requirements"],
    set: {
      answer: "Warranty is how well a product or service performs: confidence that it " +
        "will meet the requirements that were agreed, often summed up as \"fit for " +
        "use\". It covers availability, capacity, security and continuity.",
    },
  },
  {
    path: "courses/itil-v4/modules/module-2/flashcards/card-6",
    guard: ["answer", "a result for a stakeholder enabled by one or more outputs"],
    set: {
      answer: "An output is something an activity produces, physical or not: concrete " +
        "and measurable. An outcome is what a stakeholder actually gains because of " +
        "those outputs: the real change or benefit.",
    },
  },
  {
    path: "courses/itil-v4/modules/module-1/flashcards/PsLsyUz3YZmH09rAJJ5b",
    guard: ["answer", "AXELOS, a joint venture"],
    set: {
      answer: "PeopleCert. It acquired AXELOS, the previous owner (which also ran " +
        "PRINCE2), in 2021.",
    },
  },
  {
    path: "courses/itil-v4/modules/module-1/quiz/YnAEBNA96b5Hf4gMgwhA",
    guard: ["explanation", "AXELOS owns and maintains ITIL"],
    set: {
      options: ["Microsoft", "PeopleCert", "ISO", "The Open Group"],
      correctIndex: 1,
      explanation: "PeopleCert owns ITIL. It acquired AXELOS, the previous owner, in 2021.",
    },
  },
  {
    path: "courses/csm/modules/module-2/quiz/q-3",
    guard: ["explanation", "single objective for the Sprint"],
    set: {
      explanation: "The Sprint Goal is the one aim the whole Sprint works toward. It " +
        "guides the team's decisions about what matters most.",
    },
  },
  {
    path: "courses/csm/modules/module-4/flashcards/card-3",
    guard: ["answer", "15-minute event for the Developers"],
    set: {
      answer: "A short daily check-in, 15 minutes at most, where the Developers look " +
        "at how they are tracking against the Sprint Goal and plan the next day of " +
        "work, adjusting the Sprint Backlog if needed. It is not a status report " +
        "to management.",
    },
  },
];

(async () => {
  console.log(`mode: ${COMMIT ? "COMMIT - documents WILL be written" : "dry run - nothing is written"}\n`);
  let changed = 0, skipped = 0;
  for (const e of edits) {
    const ref = db.doc(e.path);
    const snap = await ref.get();
    const [field, needle] = e.guard;
    const current = snap.exists ? String(snap.data()[field] ?? "") : "";
    if (!current.includes(needle)) {
      console.log(`SKIP  ${e.path} (flagged text no longer present)`);
      skipped++;
      continue;
    }
    console.log(`EDIT  ${e.path}\n      was: ${current.slice(0, 110)}...`);
    if (COMMIT) await ref.update(e.set);
    changed++;
  }
  console.log(`\n${COMMIT ? "updated" : "would update"}: ${changed}, skipped: ${skipped}`);
})().catch((err) => { console.error("ERR", err.message); process.exit(1); });
