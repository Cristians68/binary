import 'dart:typed_data';

import 'package:binary/screens/profile_photo.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('avatarSourceFor', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    test('a custom photo beats the provider photo', () {
      expect(avatarSourceFor(custom: bytes, photoUrl: 'https://x/p.jpg'),
          AvatarSource.custom);
    });
    test('the provider photo beats initials', () {
      expect(
          avatarSourceFor(photoUrl: 'https://x/p.jpg'), AvatarSource.provider);
    });
    test('initials when there is neither', () {
      expect(avatarSourceFor(), AvatarSource.initials);
      expect(avatarSourceFor(custom: Uint8List(0), photoUrl: ''),
          AvatarSource.initials);
    });
  });

  group('isAcceptablePhoto', () {
    test('accepts exactly the cap and rejects one byte more', () {
      expect(isAcceptablePhoto(Uint8List(kMaxProfilePhotoBytes)), isTrue);
      expect(isAcceptablePhoto(Uint8List(kMaxProfilePhotoBytes + 1)), isFalse);
    });
    test('rejects empty bytes', () {
      expect(isAcceptablePhoto(Uint8List(0)), isFalse);
    });
  });

  group('ProfilePhotoService', () {
    late FakeFirebaseFirestore db;
    setUp(() {
      db = FakeFirebaseFirestore();
      ServiceBackend.useFake(db, uid: 'learner-1');
    });
    tearDown(ServiceBackend.reset);

    test('save writes only jpeg + updatedAt under the owner', () async {
      await ProfilePhotoService.save(Uint8List.fromList([9, 8, 7]));
      final doc = await db.doc('users/learner-1/profile/photo').get();
      expect(doc.data()!.keys.toSet(), {'jpeg', 'updatedAt'});
      expect((doc.data()!['jpeg'] as Blob).bytes, [9, 8, 7]);
    });
    test('watch delivers the saved bytes, then null after remove', () async {
      final seen = <List<int>?>[];
      final sub = ProfilePhotoService.watch().listen(seen.add);
      await ProfilePhotoService.save(Uint8List.fromList([5]));
      await pumpEventQueue();
      await ProfilePhotoService.remove();
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, contains(equals([5])));
      expect(seen.last, isNull);
    });
    test('save refuses an oversize photo without writing', () async {
      expect(
          () => ProfilePhotoService.save(Uint8List(kMaxProfilePhotoBytes + 1)),
          throwsArgumentError);
      final doc = await db.doc('users/learner-1/profile/photo').get();
      expect(doc.exists, isFalse);
    });
    test('watch is null with no signed-in user', () async {
      ServiceBackend.useFake(db, uid: null);
      expect(await ProfilePhotoService.watch().first, isNull);
    });
  });
}
