// Small transactional store: writes commit together, reads after writes fail.
// It does not implement Firestore security rules; those need the emulator.
function purchaseStore() {
  const docs = new Map();
  let failCommit = false;
  const snapshot = (ref) => ({ exists: docs.has(ref.path), data: () => structuredClone(docs.get(ref.path)) });
  const reference = (path) => ({
    path,
    collection: (name) => ({ doc: (id) => reference(`${path}/${name}/${id}`) }),
    get: async () => snapshot(reference(path)),
    set: async (data) => docs.set(path, structuredClone(data)),
  });
  const db = {
    collection: (name) => ({ doc: (id) => reference(`${name}/${id}`) }),
    runTransaction: async (action) => {
      const writes = [];
      const read = async (ref) => {
        if (writes.length) throw new Error("Firestore reads must precede writes");
        return snapshot(ref);
      };
      const result = await action({
        get: read,
        getAll: (...refs) => Promise.all(refs.map(read)),
        set: (ref, data, options) => writes.push({ ref, data, merge: options?.merge }),
        create: (ref, data) => writes.push({ ref, data, create: true }),
      });
      if (failCommit) throw new Error("Temporary commit failure");
      const next = new Map(docs);
      for (const { ref, data, merge, create } of writes) {
        if (create && next.has(ref.path)) throw new Error("Already exists");
        next.set(ref.path, structuredClone(merge ? { ...next.get(ref.path), ...data } : data));
      }
      docs.clear();
      next.forEach((value, key) => docs.set(key, value));
      return result;
    },
  };
  return { db, docs, setFailCommit: (value) => { failCommit = value; } };
}
module.exports = { purchaseStore };
