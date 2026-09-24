import 'dart:typed_data';

import 'package:binary/screens/profile_avatar.dart';
import 'package:binary/screens/service_backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 transparent PNG — decodable, so Image.memory paints without error.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

const _avatar = ProfileAvatar(radius: 30, initials: 'AL', photoUrl: null);

void main() {
  late FakeFirebaseFirestore db;
  setUp(() {
    db = FakeFirebaseFirestore();
    ServiceBackend.useFake(db, uid: 'learner-1');
  });
  tearDown(ServiceBackend.reset);

  testWidgets('shows initials when there is no photo', (tester) async {
    await tester.pumpWidget(_host(_avatar));
    await tester.pump();
    expect(find.text('AL'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the saved photo instead of initials', (tester) async {
    await db.doc('users/learner-1/profile/photo').set({'jpeg': Blob(_png)});
    await tester.pumpWidget(_host(_avatar));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('AL'), findsNothing);
  });

  testWidgets('falls back to initials when the bytes cannot be decoded',
      (tester) async {
    await db
        .doc('users/learner-1/profile/photo')
        .set({'jpeg': Blob(Uint8List.fromList([1, 2, 3]))});
    await tester.pumpWidget(_host(_avatar));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('AL'), findsOneWidget);
  });
}
