import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_backend.dart';

enum AvatarSource { custom, provider, initials }

/// Custom photo, then the sign-in provider's photo (Google), then initials.
AvatarSource avatarSourceFor({Uint8List? custom, String? photoUrl}) {
  if (custom != null && custom.isNotEmpty) return AvatarSource.custom;
  if (photoUrl != null && photoUrl.isNotEmpty) return AvatarSource.provider;
  return AvatarSource.initials;
}

/// Mirrors the cap in firestore.rules. The picker downsizes to 256px, which
/// lands around 20-40 KB, so this only trips on something unexpected.
const int kMaxProfilePhotoBytes = 150 * 1024;

bool isAcceptablePhoto(Uint8List bytes) =>
    bytes.isNotEmpty && bytes.length <= kMaxProfilePhotoBytes;

/// The learner's own photo, private to them, stored free on Spark.
///
/// Kept in its own document rather than on users/{uid}: that document is
/// streamed and re-delivered on every progress write, and 30 KB riding on it
/// would multiply every one of those snapshots.
class ProfilePhotoService {
  ProfilePhotoService._();

  static DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = ServiceBackend.uid;
    if (uid == null) return null;
    return ServiceBackend.db.doc('users/$uid/profile/photo');
  }

  /// Bound through [ServiceBackend.userStreams] like every account listener,
  /// so sign-out cancels it before credentials are cleared.
  static Stream<Uint8List?> watch() {
    final doc = _doc();
    if (doc == null) return Stream.value(null);
    return ServiceBackend.userStreams.bind(doc.snapshots()).map((snap) {
      final blob = snap.data()?['jpeg'];
      return blob is Blob ? blob.bytes : null;
    });
  }

  static Future<void> save(Uint8List bytes) async {
    if (!isAcceptablePhoto(bytes)) {
      throw ArgumentError('Photo must be 1..$kMaxProfilePhotoBytes bytes');
    }
    final doc = _doc();
    if (doc == null) throw StateError('No signed-in user');
    await doc.set(
        {'jpeg': Blob(bytes), 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> remove() async => _doc()?.delete();
}
