import 'dart:ui';
import 'package:flutter/widgets.dart';

/// SPoT — Wrap group/other avatars με blur όταν blurOn κι ο racyLevel δικαιολογεί.
/// Επειδή το ImageProvider (π.χ. CachedNetworkImageProvider) δεν τυλίγεται
/// απευθείας με ImageFiltered, τυλίγουμε ΟΛΟ το avatar widget (π.χ. CircleAvatar).
Widget wrapAvatarBlur({
  required bool blurOn,
  required String? racyLevel,
  required Widget child,
}) {
  final isRacy = racyLevel == 'POSSIBLE' || racyLevel == 'LIKELY';
  if (!blurOn || !isRacy) return child;
  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: child,
  );
}
