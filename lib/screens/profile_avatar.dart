import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'profile_photo.dart';

/// The learner's avatar: their own photo, else the sign-in provider's photo
/// (Google), else initials. Any image that fails to load shows initials, so a
/// bad photo can never break the screen it sits on.
///
/// [photoUrl] is passed in rather than read from FirebaseAuth here, which
/// keeps the widget free of Firebase singletons and testable.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.radius,
    required this.initials,
    required this.photoUrl,
    this.fontSize = 22,
  });

  final double radius;
  final String initials;
  final String? photoUrl;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Uint8List?>(
      stream: ProfilePhotoService.watch(),
      builder: (context, snap) {
        final custom = snap.data;
        final fallback = _initials();
        final Widget child;
        switch (avatarSourceFor(custom: custom, photoUrl: photoUrl)) {
          case AvatarSource.custom:
            child = Image.memory(custom!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback);
          case AvatarSource.provider:
            child = Image.network(photoUrl!,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
          case AvatarSource.initials:
            child = fallback;
        }
        return SizedBox.square(
          dimension: radius * 2,
          child: ClipOval(child: child),
        );
      },
    );
  }

  Widget _initials() => ColoredBox(
        color: AppColors.primary,
        child: Center(
          child: Text(initials,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700)),
        ),
      );
}
