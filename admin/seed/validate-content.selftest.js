/**
 * Mutation self-test for validate-content.js.
 *
 * A validator that reports "0 errors" is worthless until you have seen it fail.
 * This takes a known-good seed script, injects one specific fault at a time
 * into a temporary copy, and asserts the validator both exits non-zero AND
 * names that fault. If a mutation slips through, the corresponding check is
 * dead and this exits non-zero.
 *
 * Run:  node admin/seed/validate-content.selftest.js
 */

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const SOURCE = path.join(__dirname, "create-cyber-pro.js");
const VALIDATOR = path.join(__dirname, "validate-content.js");
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "seed-selftest-"));

const original = fs.readFileSync(SOURCE, "utf8");

// Each mutation: a one-off edit to the source, and the phrase the validator
// must produce in response.
const mutations = [
  {
    name: "answer key past the end of the options array",
    apply: (s) => s.replace("correctIndex: 1", "correctIndex: 9"),
    expect: /out of range/,
  },
  {
    name: "answer key that is not a number",
    apply: (s) => s.replace("correctIndex: 1", 'correctIndex: "1"'),
    expect: /not a number/,
  },
  {
    name: "two identical options where one is the answer",
    // Option strings in the seed files contain no escaped quotes, so a plain
    // [^"]* is enough and keeps this pattern readable.
    apply: (s) =>
      s.replace(
        /options: \["([^"]*)", "([^"]*)", "([^"]*)", "([^"]*)"\], correctIndex: 1/,
        'options: ["$1", "$2", "$2", "$4"], correctIndex: 1'
      ),
    expect: /same text/,
  },
  {
    name: "an empty option string",
    apply: (s) => s.replace(/options: \["([^"]*)", /, 'options: ["", '),
    expect: /is empty/,
  },
  {
    name: "a flashcard with no answer",
    apply: (s) => s.replace(/answer: "([^"]*)"/, 'answer: ""'),
    expect: /empty answer/,
  },
  {
    name: "a quiz question with no explanation",
    apply: (s) => s.replace(/explanation: "([^"]*)"/, 'explanation: ""'),
    expect: /no explanation/,
    // A blank rationale is a content-quality problem, not a broken answer
    // key, so the validator reports it without failing the run.
    severity: "warning",
  },
  {
    name: "a duplicate quiz order value",
    apply: (s) => s.replace("{ order: 2, question:", "{ order: 1, question:"),
    expect: /duplicate order/,
  },
];

function runValidator(file) {
  try {
    const out = execFileSync(process.execPath, [VALIDATOR, file], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return { code: 0, out };
  } catch (e) {
    return { code: e.status, out: (e.stdout || "") + (e.stderr || "") };
  }
}

// Control: the unmutated file must pass. If this fails, every result below is
// meaningless because the baseline is already broken.
const control = runValidator(SOURCE);
let failures = 0;
if (control.code !== 0) {
  console.log("FAIL  control: the unmodified seed script does not pass");
  console.log(control.out);
  failures++;
} else {
  console.log("ok    control: unmodified seed script passes");
}

for (const m of mutations) {
  const mutated = m.apply(original);
  if (mutated === original) {
    console.log(`FAIL  ${m.name}\n      the mutation did not change the file — the test is vacuous`);
    failures++;
    continue;
  }
  const file = path.join(tmpDir, `mutant-${mutations.indexOf(m)}.js`);
  fs.writeFileSync(file, mutated);
  const r = runValidator(file);

  const wantsFailure = m.severity !== "warning";

  if (wantsFailure && r.code === 0) {
    console.log(`FAIL  ${m.name}
      validator still exited 0 - this check is dead`);
    failures++;
  } else if (!wantsFailure && r.code !== 0) {
    console.log(`FAIL  ${m.name}
      expected a warning, but the run failed outright. Output:
${r.out}`);
    failures++;
  } else if (!m.expect.test(r.out)) {
    console.log(`FAIL  ${m.name}
      validator did not report this. Output:
${r.out}`);
    failures++;
  } else {
    console.log(`ok    caught: ${m.name}${wantsFailure ? "" : " (reported as a warning)"}`);
  }
}

fs.rmSync(tmpDir, { recursive: true, force: true });

console.log("");
if (failures) {
  console.log(`${failures} of ${mutations.length + 1} checks are not doing their job.`);
  process.exit(1);
}
console.log(`All ${mutations.length} fault classes are detected, and the clean file passes.`);
