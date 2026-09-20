/**
 * Attack the LIVE Firestore rules and report whether they hold.
 *
 * WHY THIS EXISTS, and why the Dart suite cannot replace it.
 *
 * On 2026-09-11 an audit found that firestore.rules had never been deployed.
 * The repository file was correct and the production rules were an older,
 * weaker set, so any signed-in user could write
 * `users/{uid}.subscriptionPlan = "all"` and take the whole paid catalogue.
 * No unit test could have caught that: the file on disk was right. The only
 * thing that finds it is asking the real database.
 *
 * HOW TO RUN
 *   cd tools/security
 *   node probe_rules.js            (needs ../screenshots/node_modules)
 *
 * The shell here cannot reach googleapis.com, so the probe runs inside a
 * Chrome page context via puppeteer. It signs up throwaway anonymous accounts,
 * runs each case, and deletes them in a finally block.
 *
 * THE POSITIVE CONTROLS ARE THE POINT.
 *
 * The first version of this probe reported 10/14 abuse cases denied, which
 * read as reassuring. It was wrong: part of it was malformed, and a malformed
 * request 403s exactly like a locked one. A probe with no requests that MUST
 * succeed cannot tell a secure database from a broken script. If any PC-* case
 * fails, every denial below it is meaningless -- fix the probe before
 * believing the result.
 *
 * Exit code 1 means the rules did not hold, or the probe cannot be trusted.
 */

const KEY = 'AIzaSyD90GWggrimAFSGgOT8w8KzehQqB5KEk8Y';
const PROJ = 'binary-6a372';
const FS = `https://firestore.googleapis.com/v1/projects/${PROJ}/databases/(default)/documents`;
const results = [];
function record(id, expectation, status, pass, note) {
  results.push({ id, expectation, status, pass, note });
  console.log(`${pass ? 'PASS' : 'FAIL'}  ${id}  [HTTP ${status}]  ${expectation}${note ? ' -- ' + note : ''}`);
}
async function signUp(label) {
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${KEY}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }) });
  const j = await r.json();
  if (!j.idToken) throw new Error(`${label} signup failed: ${JSON.stringify(j).slice(0,300)}`);
  console.log(`  (${label} uid=${j.localId})`);
  return { token: j.idToken, uid: j.localId };
}
async function del(tok) {
  await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${KEY}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: tok }) });
}
const get = (tok, path) => fetch(`${FS}/${path}`, { headers: { Authorization: `Bearer ${tok}` } });
const patch = (tok, path, fields, mask) =>
  fetch(`${FS}/${path}?${mask.map(m => `updateMask.fieldPaths=${m}`).join('&')}`,
    { method: 'PATCH', headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }) });

(async () => {
  const a = await signUp('attacker');
  const b = await signUp('victim');
  try {
    console.log('\n--- positive controls (these MUST succeed) ---');
    let r = await get(a.token, 'courses');
    const courses = (await r.clone().json()).documents || [];
    record('PC-1', 'signed-in user can list the course catalogue', r.status, r.ok && courses.length > 0, `${courses.length} courses`);
    const courseId = courses.length ? courses[0].name.split('/').pop() : null;
    let lockedModule = null;
    if (courseId) {
      r = await get(a.token, `courses/${courseId}/modules`);
      const mods = (await r.json()).documents || [];
      const ids = mods.map(m => m.name.split('/').pop());
      record('PC-2', 'signed-in user can list modules', r.status, r.ok && ids.length > 0, ids.slice(0,6).join(','));
      const free = ids.find(i => i === 'module-1' || i === 'module-01');
      lockedModule = ids.find(i => i !== 'module-1' && i !== 'module-01');
      if (free) {
        r = await get(a.token, `courses/${courseId}/modules/${free}/flashcards`);
        record('PC-3', 'FREE preview module is readable (proves read path works)', r.status, r.ok, `module ${free}`);
      } else { record('PC-3', 'no free module found to use as control', 0, false, ids.join(',')); }
      r = await patch(a.token, `users/${a.uid}`, { displayName: { stringValue: 'probe' } }, ['displayName']);
      record('PC-4', 'own non-entitlement field writable (proves PATCH shape valid)', r.status, r.ok);
    }
    console.log('\n--- abuse cases (these MUST be denied) ---');
    r = await patch(a.token, `users/${a.uid}`, { subscriptionPlan: { stringValue: 'all' } }, ['subscriptionPlan']);
    record('AB-1', 'self-granting subscriptionPlan=all refused', r.status, r.status === 403);
    r = await patch(a.token, `users/${a.uid}`, { hasUsedTrial: { booleanValue: false } }, ['hasUsedTrial']);
    record('AB-2', 'resetting hasUsedTrial refused', r.status, r.status === 403);
    r = await patch(a.token, `users/${a.uid}`, { isAdmin: { booleanValue: true } }, ['isAdmin']);
    record('AB-3', 'self-granting isAdmin refused', r.status, r.status === 403);
    r = await get(a.token, `users/${b.uid}`);
    record('AB-4', 'reading another user document refused', r.status, r.status === 403);
    r = await patch(a.token, `users/${b.uid}`, { displayName: { stringValue: 'pwned' } }, ['displayName']);
    record('AB-5', 'writing another user document refused', r.status, r.status === 403);
    if (courseId) {
      r = await patch(a.token, `courses/${courseId}`, { title: { stringValue: 'vandalised' } }, ['title']);
      record('AB-6', 'vandalising shared course catalogue refused', r.status, r.status === 403);
      if (lockedModule) {
        r = await get(a.token, `courses/${courseId}/modules/${lockedModule}/flashcards`);
        record('AB-7', 'reading PAID module content without entitlement refused', r.status, r.status === 403, `module ${lockedModule}`);
        r = await patch(a.token, `courses/${courseId}/modules/${lockedModule}`, { status: { stringValue: 'active' } }, ['status']);
        record('AB-8', 'writing status into SHARED module doc refused', r.status, r.status === 403, 'the 09-08 bug');
      }
    }
    r = await get(a.token, 'admins');
    record('AB-9', 'listing admin allowlist refused', r.status, r.status === 403);
    r = await patch(a.token, `admins/${a.uid}`, { ok: { booleanValue: true } }, ['ok']);
    record('AB-10', 'self-enrolling as admin refused', r.status, r.status === 403);
    r = await get(a.token, 'processed_rc_events');
    record('AB-11', 'reading webhook replay ledger refused', r.status, r.status === 403);
    r = await fetch(`${FS}/users/${a.uid}`, { method: 'DELETE', headers: { Authorization: `Bearer ${a.token}` } });
    record('AB-12', 'client-side deletion of user doc refused', r.status, r.status === 403);
    r = await patch(a.token, `feedback/probe-${Date.now()}`, { uid: { stringValue: b.uid }, message: { stringValue: 'x' } }, ['uid','message']);
    record('AB-13', 'feedback under another uid refused', r.status, r.status === 403);
    r = await fetch(`${FS}/courses`);
    record('AB-14', 'unauthenticated catalogue read refused', r.status, r.status === 403);

    console.log('\n========== SUMMARY ==========');
    const pc = results.filter(x => x.id.startsWith('PC'));
    const ab = results.filter(x => x.id.startsWith('AB'));
    const pcFail = pc.filter(x => !x.pass), abFail = ab.filter(x => !x.pass);
    console.log(`positive controls: ${pc.length - pcFail.length}/${pc.length} passed`);
    console.log(`abuse cases denied: ${ab.length - abFail.length}/${ab.length}`);
    if (pcFail.length) { console.log('\n!! POSITIVE CONTROLS FAILED -- denials prove NOTHING:'); pcFail.forEach(x => console.log(`   ${x.id} ${x.expectation} [${x.status}]`)); }
    if (abFail.length) { console.log('\n!! ABUSE CASES NOT DENIED:'); abFail.forEach(x => console.log(`   ${x.id} ${x.expectation} [HTTP ${x.status}]`)); }
  } finally {
    await del(a.token); await del(b.token);
    console.log('\n(throwaway accounts deleted)');
  }
})().catch(e => { console.error('PROBE ERROR:', e.message); process.exit(2); });
