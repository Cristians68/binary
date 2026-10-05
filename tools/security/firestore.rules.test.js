// Runs only against the local demo project. All content and accounts here are
// fictional; neither Firebase credentials nor production reads are needed.
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const path = require('node:path');
const {before, beforeEach, after, test} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} =
  require('@firebase/rules-unit-testing');
const {
  doc, collection, getDocFromServer, getDocsFromServer, setDoc, updateDoc,
  deleteDoc, deleteField, writeBatch, Timestamp, Bytes, setLogLevel,
} = require('firebase/firestore');
const {COURSE_IDS} = require('../../functions/purchase_catalog');

const projectId = 'demo-binary-release';
const courses = [...COURSE_IDS];
const [courseA, courseB, courseC] = courses;
const contentKinds = ['body', 'flashcards', 'quiz'];
let environment;
let learner;
let other;
let signedOut;

const contentPath = (course, module = 'module-2', kind = 'body') =>
  `courses/${course}/modules/${module}/${kind}/example`;
const read = (db, documentPath) => getDocFromServer(doc(db, documentPath));
const readList = (db, collectionPath) => getDocsFromServer(collection(db, collectionPath));
const save = (db, documentPath, data) => setDoc(doc(db, documentPath), data);

async function seed(entries) {
  await environment.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    const batch = writeBatch(db);
    for (const [documentPath, data] of entries) batch.set(doc(db, documentPath), data);
    await batch.commit();
  });
}

async function grant(profile, purchasedCourseIds) {
  await seed([
    ['users/learner', {name: 'Test learner', ...profile}],
    ['users/learner/purchaseState/current', {purchasedCourseIds}],
  ]);
}

before(async () => {
  // The runner supplies this; refusing a missing or remote host prevents an
  // accidental plain `node --test` from silently reaching a real project.
  const address = process.env.FIRESTORE_EMULATOR_HOST || '';
  assert.match(address, /^127\.0\.0\.1:\d+$/, 'Run npm test with the local emulator');
  const port = Number(address.split(':')[1]);
  assert.ok(port > 0 && port < 65536);
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1', port,
      rules: readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
  setLogLevel('silent'); // Permission-denied writes are expected assertions.
  learner = environment.authenticatedContext('learner').firestore();
  other = environment.authenticatedContext('other').firestore();
  signedOut = environment.unauthenticatedContext().firestore();
});

beforeEach(async () => {
  await environment.clearFirestore();
  const entries = [['users/learner', {name: 'Test learner'}],
    ['users/other', {name: 'Another learner'}]];
  for (const course of courses) {
    entries.push([`courses/${course}`, {title: 'Fictional test course'}]);
    for (const module of ['module-1', 'module-01', 'module-2']) {
      entries.push([`courses/${course}/modules/${module}`, {title: 'Test module'}]);
      for (const kind of contentKinds) {
        entries.push([contentPath(course, module, kind), {text: 'Synthetic content'}]);
      }
    }
  }
  await seed(entries);
});

after(async () => environment?.cleanup());

test('a guest can browse metadata and every preview content collection', async () => {
  const guest = environment.authenticatedContext('guest', {
    firebase: {sign_in_provider: 'anonymous', identities: {}},
  }).firestore();
  assert.equal((await assertSucceeds(readList(guest, 'courses'))).size, courses.length);
  for (const course of courses) {
    assert.equal((await assertSucceeds(readList(guest, `courses/${course}/modules`))).size, 3);
    for (const module of ['module-1', 'module-01']) {
      for (const kind of contentKinds) {
        assert.equal((await assertSucceeds(read(guest, contentPath(course, module, kind)))).exists(), true);
        assert.equal((await assertSucceeds(readList(guest,
          `courses/${course}/modules/${module}/${kind}`))).size, 1);
      }
    }
  }
  await assertFails(read(guest, contentPath(courseA)));
});

test('signed-out requests cannot read even previews or catalogue metadata', async () => {
  await assertFails(readList(signedOut, 'courses'));
  await assertFails(read(signedOut, `courses/${courseA}`));
  await assertFails(read(signedOut, `courses/${courseA}/modules/module-1`));
  for (const kind of contentKinds) {
    await assertFails(read(signedOut, contentPath(courseA, 'module-1', kind)));
  }
});

test('an unpaid learner cannot read paid documents or query around the paywall', async () => {
  for (const kind of contentKinds) {
    await assertFails(read(learner, contentPath(courseA, 'module-2', kind)));
    await assertFails(readList(learner, `courses/${courseA}/modules/module-2/${kind}`));
  }
});

test('two separate course purchases grant both courses and deny the third', async () => {
  await grant({subscriptionPlan: 'single', subscribedCourseId: courseA,
    purchasedCourseIds: [courseA, courseB]}, [courseA, courseB]);
  for (const course of [courseA, courseB]) {
    for (const kind of contentKinds) {
      assert.equal((await assertSucceeds(read(learner, contentPath(course, 'module-2', kind)))).exists(), true);
      assert.equal((await assertSucceeds(readList(learner,
        `courses/${course}/modules/module-2/${kind}`))).size, 1);
    }
  }
  await assertFails(read(learner, contentPath(courseC)));
  await assertFails(read(other, contentPath(courseA)));
});

test('a forged old profile list cannot authorize an additional course', async () => {
  await seed([['users/learner', {subscriptionPlan: 'single',
    subscribedCourseId: courseA, purchasedCourseIds: [courseB]}]]);
  await assertSucceeds(read(learner, contentPath(courseA)));
  await assertFails(read(learner, contentPath(courseB)));
  await seed([['users/learner/purchaseState/current', {purchasedCourseIds: []}]]);
  await assertFails(read(learner, contentPath(courseB)));
});

test('a four-course bundle and an extra single course coexist', async () => {
  const bundle = courses.slice(0, 4);
  const extra = courses[4];
  await grant({subscriptionPlan: 'bundle4', bundleCourseIds: bundle}, [...bundle, extra]);
  for (const course of [...bundle, extra]) await assertSucceeds(read(learner, contentPath(course)));
  await assertFails(read(learner, contentPath(courses[5])));
});

test('All Courses grants the entire catalogue', async () => {
  await grant({subscriptionPlan: 'all'}, []);
  for (const course of courses) await assertSucceeds(read(learner, contentPath(course)));
});

test('a bundle owner can use an unexpired trial for another course', async () => {
  await grant({subscriptionPlan: 'bundle4', bundleCourseIds: courses.slice(0, 4),
    trialCourseId: courses[4], trialExpiry: Timestamp.fromMillis(Date.now() + 3600000)},
  courses.slice(0, 4));
  await assertSucceeds(read(learner, contentPath(courses[4])));
  await assertFails(read(learner, contentPath(courses[5])));
});

test('expired and incomplete trials grant no paid content', async () => {
  for (const fields of [
    {trialCourseId: courseA, trialExpiry: Timestamp.fromMillis(Date.now() - 3600000)},
    {trialCourseId: courseA},
    {trialExpiry: Timestamp.fromMillis(Date.now() + 3600000)},
  ]) {
    await seed([['users/learner', fields]]);
    await assertFails(read(learner, contentPath(courseA)));
  }
});

test('refund and transfer updates revoke only the access removed by the server', async () => {
  await grant({subscriptionPlan: 'single', subscribedCourseId: courseA}, [courseA, courseB]);
  await assertSucceeds(read(learner, contentPath(courseB)));
  await grant({subscriptionPlan: 'single', subscribedCourseId: courseA}, [courseA]);
  await assertFails(read(learner, contentPath(courseB)));
  await assertSucceeds(read(learner, contentPath(courseA)));
  await grant({subscriptionPlan: 'none'}, []);
  await seed([
    ['users/other', {subscriptionPlan: 'single', subscribedCourseId: courseA}],
    ['users/other/purchaseState/current', {purchasedCourseIds: [courseA]}],
  ]);
  await assertFails(read(learner, contentPath(courseA)));
  await assertSucceeds(read(other, contentPath(courseA)));
});

test('a pending checkout or unresolved receipt grants no access', async () => {
  await seed([
    ['users/learner', {subscriptionPlan: 'none', pendingCourseId: courseA,
      pendingBundleCourseIds: [courseA, courseB, courseC, courses[3]]}],
    ['users/learner/purchaseIntents/binary_bundle_4', {courseIds: courses.slice(0, 4)}],
    ['users/learner/purchaseState/current', {purchasedCourseIds: [],
      unresolvedPurchaseProductIds: ['binary_bundle_4']}],
  ]);
  await assertFails(read(learner, contentPath(courseA)));
});

test('profile create, update and field removal cannot forge entitlements or admin access', async () => {
  const protectedFields = {
    subscriptionPlan: 'all', subscriptionUpdatedAt: Timestamp.now(),
    subscribedCourseId: courseA, bundleCourseIds: courses.slice(0, 4),
    purchasedCourseIds: [courseA], pendingCourseId: courseA,
    pendingBundleCourseIds: courses.slice(0, 4), trialCourseId: courseA,
    trialExpiry: Timestamp.now(), trialStartedAt: Timestamp.now(),
    hasUsedTrial: true, role: 'admin', isAdmin: true,
  };
  const newcomer = environment.authenticatedContext('newcomer').firestore();
  for (const [field, value] of Object.entries(protectedFields)) {
    await assertFails(save(newcomer, 'users/newcomer', {[field]: value}));
    await assertFails(updateDoc(doc(learner, 'users/learner'), {[field]: value}));
  }
  await seed([['users/learner', {name: 'Test learner', ...protectedFields}]]);
  for (const field of Object.keys(protectedFields)) {
    await assertFails(updateDoc(doc(learner, 'users/learner'), {[field]: deleteField()}));
  }
  await assertSucceeds(updateDoc(doc(learner, 'users/learner'), {name: 'Updated learner'}));
  await assertSucceeds(setDoc(doc(learner, 'users/learner'),
    {name: 'Merged learner', subscriptionPlan: 'all'}, {merge: true}));
  await assertFails(deleteDoc(doc(learner, 'users/learner')));
});

test('private purchase state, intents, receipt bindings and replay markers stay server-only', async () => {
  const privatePaths = [
    'users/learner/purchaseState/current',
    'users/learner/purchaseIntents/binary_bundle_4',
    'purchase_bindings/test-receipt',
    'processed_rc_events/test-event',
  ];
  for (const documentPath of privatePaths) {
    await assertFails(save(learner, documentPath, {purchasedCourseIds: [courseA]}));
  }
  await seed(privatePaths.map(documentPath => [documentPath, {test: true}]));
  for (const db of [learner, other, signedOut]) {
    for (const documentPath of privatePaths) {
      await assertFails(read(db, documentPath));
      await assertFails(readList(db, documentPath.substring(0, documentPath.lastIndexOf('/'))));
      await assertFails(save(db, documentPath, {test: false}));
      await assertFails(deleteDoc(doc(db, documentPath)));
    }
  }
});

test('owners can save study progress and attempts but cannot access another account', async () => {
  const progressPaths = [
    `users/learner/progress/${courseA}`,
    `users/learner/progress/${courseA}/modules/module-1`,
    `users/learner/progress/${courseA}/modules/module-1/attempts/attempt-1`,
  ];
  await assertSucceeds(updateDoc(doc(learner, 'users/learner'), {lessonsCompleted: 1}));
  for (const documentPath of progressPaths) {
    await assertSucceeds(save(learner, documentPath, {score: 100}));
    await assertSucceeds(read(learner, documentPath));
    await assertFails(read(other, documentPath));
    await assertFails(save(other, documentPath, {score: 0}));
  }
  await assertFails(read(other, 'users/learner'));
  await assertFails(updateDoc(doc(other, 'users/learner'), {name: 'Someone else'}));
  await assertFails(readList(learner, 'users'));
});

test('profile photos are private and enforce the real byte limit and shape', async () => {
  const photo = 'users/learner/profile/photo';
  const maxPhoto = Bytes.fromUint8Array(new Uint8Array(150 * 1024));
  await assertSucceeds(save(learner, photo, {jpeg: maxPhoto, updatedAt: Timestamp.now()}));
  await assertSucceeds(read(learner, photo));
  await assertFails(read(other, photo));
  await assertFails(save(other, photo, {jpeg: maxPhoto}));
  await assertFails(save(learner, photo, {jpeg: Bytes.fromUint8Array(new Uint8Array(150 * 1024 + 1))}));
  await assertFails(save(learner, photo, {jpeg: 'not bytes'}));
  await assertFails(save(learner, photo, {jpeg: maxPhoto, public: true}));
  await assertSucceeds(deleteDoc(doc(learner, photo)));
});

test('only an allowlisted administrator can edit shared course content', async () => {
  const targets = [`courses/${courseA}`, `courses/${courseA}/modules/module-2`, contentPath(courseA)];
  for (const documentPath of targets) {
    await assertFails(save(learner, documentPath, {title: 'Changed'}));
    await assertFails(deleteDoc(doc(learner, documentPath)));
  }
  await assertFails(save(learner, 'admins/learner', {enabled: true}));
  await seed([['admins/editor', {enabled: true}]]);
  const editor = environment.authenticatedContext('editor').firestore();
  for (const documentPath of targets) await assertSucceeds(save(editor, documentPath, {title: 'Changed'}));
});
