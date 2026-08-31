import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// The single seam between the static services and Firebase.
///
/// [StreakService], [ProgressService] and [SubscriptionService] are static
/// classes that reached straight for `FirebaseFirestore.instance` and
/// `FirebaseAuth.instance`. Both are singletons that throw unless a real
/// Firebase app has been initialised, which is why none of them had a single
/// test: there was no way to run them without a live project.
///
/// Routing every access through here lets a test swap in a fake Firestore and
/// a fixed uid. Production behaviour is unchanged — with no override set, the
/// getters return exactly what the services used to call directly.
class ServiceBackend {
  ServiceBackend._();

  static FirebaseFirestore? _dbOverride;
  static String? Function()? _uidOverride;

  static FirebaseFirestore get db => _dbOverride ?? FirebaseFirestore.instance;

  static String? get uid => _uidOverride != null
      ? _uidOverride!()
      : FirebaseAuth.instance.currentUser?.uid;

  @visibleForTesting
  static void useFake(FirebaseFirestore firestore, {String? uid}) {
    _dbOverride = firestore;
    _uidOverride = () => uid;
  }

  @visibleForTesting
  static void reset() {
    _dbOverride = null;
    _uidOverride = null;
  }
}

/// Expand Firestore dot-notation keys into the nested maps `set()` expects.
///
/// `update({'streak.current': 3})` addresses a field *inside* the `streak` map.
/// `set({'streak.current': 3}, merge: true)` does not: it creates a top-level
/// field whose name literally contains a dot. The two are not interchangeable,
/// so any code that falls back from one to the other has to translate.
///
/// `{'streak.current': 3, 'streak.longest': 9}` becomes
/// `{'streak': {'current': 3, 'longest': 9}}`.
///
/// Values pass through untouched, so `FieldValue` sentinels (`arrayUnion`,
/// `increment`, `serverTimestamp`) keep working. A merging `set()` recurses
/// into nested maps, so sibling fields the caller did not mention survive —
/// which is what `update()` would have done.
Map<String, Object?> expandDotNotation(Map<String, Object?> data) {
  final out = <String, Object?>{};
  data.forEach((key, value) {
    if (!key.contains('.')) {
      out[key] = value;
      return;
    }
    final parts = key.split('.');
    var node = out;
    for (var i = 0; i < parts.length - 1; i++) {
      final existing = node[parts[i]];
      if (existing is Map<String, Object?>) {
        node = existing;
      } else {
        // A scalar already sitting at this path is being replaced by a map.
        // Mixing 'a' and 'a.b' in one write is ambiguous either way; the
        // deeper key wins, matching how the callers actually use this.
        final child = <String, Object?>{};
        node[parts[i]] = child;
        node = child;
      }
    }
    node[parts.last] = value;
  });
  return out;
}

/// `update()` with a `set(merge: true)` fallback for a document that does not
/// exist yet.
///
/// The fallback expands dot-notation first. Without that, the first write to a
/// missing document silently creates literal `"streak.current"` fields that
/// nothing ever reads again — see `test/streak_service_test.dart`.
Future<void> safeUpdate(
  DocumentReference<Map<String, dynamic>> doc,
  Map<String, Object?> data,
) async {
  try {
    await doc.update(data);
  } catch (_) {
    await doc.set(expandDotNotation(data), SetOptions(merge: true));
  }
}
