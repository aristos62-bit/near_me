import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/services/vision_moderation_service.dart';

/// Fail-open paths του `VisionModerationService` — χωρίς δίκτυο.
/// (Το CF-unavailable πιάνεται στο generic catch → approved.)
void main() {
  group('VisionModerationService fail-open', () {
    test('empty bytes → allow', () async {
      final res =
          await VisionModerationService.isProfilePhotoSafe(Uint8List(0));
      expect(res.approved, isTrue);
    });

    test('πάνω από 6MB → skip check, allow', () async {
      final big = Uint8List(6 * 1024 * 1024 + 1);
      final res = await VisionModerationService.isChatMediaSafe(big);
      expect(res.approved, isTrue);
      expect(res.racyLevel, 'VERY_UNLIKELY');
    });

    test('χωρίς Firebase app → fail-open allow (όχι throw)', () async {
      final res = await VisionModerationService.isGroupAvatarSafe(
          Uint8List.fromList([1, 2, 3]));
      expect(res.approved, isTrue);
    });

    test('isSafe με μικρά bytes χωρίς app → allow', () async {
      final res = await VisionModerationService.isSafe(
          Uint8List.fromList([1, 2, 3]));
      expect(res.approved, isTrue);
    });
  });
}
