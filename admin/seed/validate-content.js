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
 * Checks agree with the app parser: quiz answers must be distinct strings,
 * answer keys must be integers, and a malformed module must never turn into
 * a shorter, easier quiz. Missing explanations also block publication.
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
  checkOrder(where, q.order);
  const opts = q.options;
  if (!Array.isArray(opts) || opts.length < 2) {
    err(where, `options must contain at least two answers`);
    return;
  }
  if (opts.length !== 4) {
    warn(where, `${opts.length} options (every other question has 4)`);
  }
  if (typeof q.correctIndex !== "number") {
    err(where, `correctIndex is ${JSON.stringify(q.correctIndex)}, not a number`);
    return;
  }
  if (!Number.isInteger(q.correctIndex)) {
    err(where, `correctIndex must be a finite integer`);
  }
  if (q.correctIndex < 0 || q.correctIndex >= opts.length) {
    err(where, `correctIndex ${q.correctIndex} is out of range for ${opts.length} options`);
  }
  // Case-only differences do not make meaningful distractors.
  const seen = new Map();
  opts.forEach((o, i) => {
    const key = String(o).trim().toLowerCase();
    if (seen.has(key)) {
      const first = seen.get(key);
      const detail = `options ${first} and ${i} are the same text: ${JSON.stringify(o)}`;
      err(where, detail);
    } else {
      seen.set(key, i);
    }
  });
  if (typeof q.question !== 'string' || !q.question.trim()) err(where, `empty question text or question is not a string`);
  if (typeof q.explanation !== 'string' || !q.explanation.trim()) {
    err(where, `no explanation — every published question needs a rationale`);
  }
  opts.forEach((o, i) => {
    if (typeof o !== 'string') err(where, `option ${i} is not a string`);
    else if (!o.trim()) err(where, `option ${i} is empty`);
  });
}

function checkFlashcard(where, c) {
  if (typeof c.question !== 'string' || !c.question.trim()) err(where, `empty question or question is not a string`);
  if (typeof c.answer !== 'string' || !c.answer.trim()) err(where, `empty answer or answer is not a string`);
  checkOrder(where, c.order);
}

function checkOrder(where, order) {
  if (!Number.isInteger(order) || order < 1) err(where, `order must be a positive integer`);
}

// ── Drive the seed scripts ──────────────────────────────────────────────────
const DEFAULT_SCRIPTS = [
  "create-network-pro.js",
  "create-cloud.js",
  "create-cloud-pro.js",
  "create-cyber-pro.js",
  "create-ai.js",
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
  console.log('Offline seed validation only: Firebase writes are intercepted.');
  let totalCards = 0;
  let totalQuizzes = 0;
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
    const paths = new Set();

    for (const w of writes) {
      const p = w.pathParts;
      const label = `${s} :: ${p.join("/")}`;
      const documentPath = p.join('/');
      if (paths.has(documentPath)) err(label, 'duplicate document write would overwrite content');
      paths.add(documentPath);
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
    if (cards === 0 || quizzes === 0) err(s, 'no flashcards or quiz questions captured');
    totalCards += cards;
    totalQuizzes += quizzes;
    console.log(`${s.padEnd(24)} ${String(modules).padStart(3)} modules  ${String(cards).padStart(4)} flashcards  ${String(quizzes).padStart(4)} quiz questions`);
  }

  console.log("");
  console.log(`Validated ${scripts.length} scripts: ${totalCards} flashcards, ${totalQuizzes} quiz questions.`);
  for (const w of warnings) console.log(w);
  if (warnings.length) console.log("");
  for (const e of errors) console.log(e);
  console.log("");
  console.log(`${errors.length} error(s), ${warnings.length} warning(s)`);
  realExit(errors.length ? 1 : 0);
})();
