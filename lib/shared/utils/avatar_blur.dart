import 'dart:ui';
import 'package:flutter/widgets.dart';

/// SPoT — Wrap group/other avatars με blur όταν blurOn κι ο racyLevel δικαιολογεί.
/// Επειδή το ImageProvider (π.χ. CachedNetworkImageProvider) δεν τυλίγεται
/// απευθείας με ImageFiltered, τυλίγουμε ΟΛΟ το avatar widget (π.χ. CircleAvatar).
bool isRacyLevel(String? level) =>
    level == 'POSSIBLE' || level == 'LIKELY' || level == 'VERY_LIKELY';

Widget wrapAvatarBlur({
  required bool blurOn,
  required String? racyLevel,
  required Widget child,
  double sigma = 12.0,
}) {
  if (!blurOn || !isRacyLevel(racyLevel) || sigma <= 0) return child;
  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: child,
  );
}
