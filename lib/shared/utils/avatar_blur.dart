import 'dart:ui';
import 'package:flutter/widgets.dart';

/// SPoT — Wrap group/other avatars με blur όταν blurOn κι ο racyLevel δικαιολογεί.
/// Επειδή το ImageProvider (π.χ. CachedNetworkImageProvider) δεν τυλίγεται
/// απευθείας με ImageFiltered, τυλίγουμε ΟΛΟ το avatar widget (π.χ. CircleAvatar).
bool isRacyLevel(String? level) => level == 'POSSIBLE' || level == 'LIKELY';

Widget wrapAvatarBlur({
  required bool blurOn,
  required String? racyLevel,
  required Widget child,
}) {
  if (!blurOn || !isRacyLevel(racyLevel)) return child;
  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: child,
  );
}
