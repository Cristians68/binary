/**
 * Offline content validator for the seed scripts. Writes NOTHING.
 *
 * WHY THIS EXISTS
 * ---------------
 * The seed scripts hold ~1,000 hand-written flashcard and quiz items. Reading
 * them by eye does not reliably catch the failure modes that actually hurt:
 * an out-of-range answer key, two identical options in one question, or a
 * question whose "correct" option is a duplicate string.
 *
 * That last one is not hypothetical. QuizScreen._shuffleQuestions does:
 *
 *     final correctAnswer = answers[q['correct']];
 *     answers.shuffle(rng);
 *     final newCorrectIndex = answers.indexOf(correctAnswer);
 *
 * `indexOf` returns the FIRST match. If a question contains the same option
 * text twice and that text is the correct answer, a user who taps the second
 * copy is marked wrong for choosing a string that is character-for-character
 * the right answer. And `answers[q['correct']]` throws RangeError on an
 * out-of-range key, which drops the whole module into the hardcoded-question
 * fallback with no visible error.
 *
 * Run:  node admin/seed/validate-content.js
 * Exits non-zero if any ERROR-level problem is found, so it can gate a commit.
 *
 * It stubs firebase-admin, so it needs no credentials and cannot touch
 * production. The seed scripts call main() at import time; requiring them
 * under the stub is what drives the collection.
 */

const Module = require("module");
const path = require("path");

// ── Recording stub for firebase-admin ───────────────────────────────────────
const writes = []; // { pathParts: string[], data: object }

function makeCollection(pathParts) {
  return {
    doc(id) {
      const p = [...pathParts, id];
      return {
        collection: (name) => makeCollection([...p, name]),
        async set(data) {
          writes.push({ pathParts: p, data });
        },
        // Report "does not exist" so createModule() always proceeds and we
        // capture the full payload rather than half of it.
        async get() {
          return { exists: false, data: () => ({}) };
        },
      };
    },
  };
}

const adminStub = {
  initializeApp() {},
  credential: { applicationDefault: () => ({}) },
  firestore: Object.assign(() => ({ collection: (n) => makeCollection([n]) }), {
    FieldValue: { serverTimestamp: () => "<serverTimestamp>" },
  }),
};

const realLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === "firebase-admin") return adminStub;
  return realLoad.apply(this, arguments);
};

// Stop the seed scripts' trailing process.exit(0) from ending the validator.
const realExit = process.exit;
process.exit = () => {};

// ── Checks ──────────────────────────────────────────────────────────────────
const errors = [];
const warnings = [];

function err(where, msg) {
  errors.push(`ERROR  ${where}\n       ${msg}`);
}
function warn(where, msg) {
  warnings.push(`WARN   ${where}\n       ${msg}`);
}

function checkQuiz(where, q) {
  const opts = q.options;
  if (!Array.isArray(opts) || opts.length === 0) {
    err(where, `no options array`);
    return;
  }
  if (opts.length !== 4) {
    warn(where, `${opts.length} options (every other question has 4)`);
  }
  if (typeof q.correctIndex !== "number") {
    err(where, `correctIndex is ${JSON.stringify(q.correctIndex)}, not a number`);
    return;
  }
  // RangeError in QuizScreen._shuffleQuestions -> silent fallback to hardcoded questions.
  if (q.correctIndex < 0 || q.correctIndex >= opts.length) {
    err(where, `correctIndex ${q.correctIndex} is out of range for ${opts.length} options`);
  }
  // Duplicate options break indexOf() after the shuffle.
  const seen = new Map();
  opts.forEach((o, i) => {
    const key = String(o).trim().toLowerCase();
    if (seen.has(key)) {
      const first = seen.get(key);
      const involvesAnswer = q.correctIndex === i || q.correctIndex === first;
      const detail = `options ${first} and ${i} are the same text: ${JSON.stringify(o)}`;
      if (involvesAnswer) {
        err(where, `${detail} — and one of them is the answer, so indexOf() after the shuffle can mark a correct tap wrong`);
      } else {
        warn(where, detail);
      }
    } else {
      seen.set(key, i);
    }
  });
  if (!q.question || !String(q.question).trim()) err(where, `empty question text`);
  if (!q.explanation || !String(q.explanation).trim()) {
    warn(where, `no explanation — the score screen shows a blank rationale`);
  }
  opts.forEach((o, i) => {
    if (!String(o).trim()) err(where, `option ${i} is empty`);
  });
}

function checkFlashcard(where, c) {
  if (!c.question || !String(c.question).trim()) err(where, `empty question`);
  if (!c.answer || !String(c.answer).trim()) err(where, `empty answer`);
  if (typeof c.order !== "number") err(where, `order is not a number`);
}

// ── Drive the seed scripts ──────────────────────────────────────────────────
const DEFAULT_SCRIPTS = [
  "create-network-pro.js",
  "create-cloud.js",
  "create-cloud-pro.js",
  "create-cyber-pro.js",
  "expand-itil-v4.js",
  "expand-csm.js",
];

// Explicit paths may be passed as arguments. That is how the mutation self-test
// in `validate-content.selftest.js` points the validator at a deliberately
// broken copy to prove these checks can actually fail.
const scripts = process.argv.slice(2).length
  ? process.argv.slice(2)
  : DEFAULT_SCRIPTS;

(async () => {
  for (const s of scripts) {
    writes.length = 0;
    const file = path.isAbsolute(s) ? s : path.join(__dirname, s);
    delete require.cache[require.resolve(file)];
    try {
      require(file);
    } catch (e) {
      err(s, `threw while loading: ${e.message}`);
      continue;
    }
    // main() is async and started at import; let its microtasks drain.
    await new Promise((r) => setImmediate(r));
    await new Promise((r) => setImmediate(r));
    await new Promise((r) => setTimeout(r, 50));

    let quizzes = 0;
    let cards = 0;
    let modules = 0;
    const orderSeen = new Map();

    for (const w of writes) {
      const p = w.pathParts;
      const label = `${s} :: ${p.join("/")}`;
      const kind = p.length >= 6 ? p[4] : null; // courses/<id>/modules/<mid>/<kind>/<docid>
      if (kind === "quiz") {
        quizzes++;
        checkQuiz(label, w.data);
        const mk = `${p[1]}/${p[3]}/quiz`;
        if (!orderSeen.has(mk)) orderSeen.set(mk, new Set());
        const set = orderSeen.get(mk);
        if (set.has(w.data.order)) err(label, `duplicate order ${w.data.order}; the quiz screen sorts by it`);
        set.add(w.data.order);
      } else if (kind === "flashcards") {
        cards++;
        checkFlashcard(label, w.data);
        const mk = `${p[1]}/${p[3]}/flashcards`;
        if (!orderSeen.has(mk)) orderSeen.set(mk, new Set());
        const set = orderSeen.get(mk);
        if (set.has(w.data.order)) err(label, `duplicate order ${w.data.order}`);
        set.add(w.data.order);
      } else if (p.length === 4 && p[2] === "modules") {
        modules++;
      }
    }
    console.log(`${s.padEnd(24)} ${String(modules).padStart(3)} modules  ${String(cards).padStart(4)} flashcards  ${String(quizzes).padStart(4)} quiz questions`);
  }

  console.log("");
  for (const w of warnings) console.log(w);
  if (warnings.length) console.log("");
  for (const e of errors) console.log(e);
  console.log("");
  console.log(`${errors.length} error(s), ${warnings.length} warning(s)`);
  realExit(errors.length ? 1 : 0);
})();
