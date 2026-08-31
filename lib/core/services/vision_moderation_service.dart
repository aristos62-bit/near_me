import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../config/feature_flags.dart';
import '../debug/debug_config.dart';

/// SPoT — Automated image moderation (SafeSearch / Vision).
///
/// Όταν `contentModerationEnabled=false` (default v1) → πάντα `approved`
/// (0 Vision calls, $0, 0 latency). Όταν `true` → καλεί το Cloud Function
/// `checkImageModeration`, που τρέχει πραγματικό Google Cloud Vision
/// SafeSearch. Fail-open σε timeout/σφάλμα — δεν μπλοκάρει legitimate
/// uploads αν η υπηρεσία είναι εκτός λειτουργίας.
typedef ModerationResult = ({bool approved, String racyLevel});

class VisionModerationService {
  const VisionModerationService._();

  static const _region = 'europe-west1';
  static const _timeout = Duration(seconds: 4);
  // Ασφαλές όριο πριν το encode σε base64 (~33% μεγαλύτερο από raw) — πάνω
  // από αυτό παραλείπουμε τον έλεγχο (fail-open) αντί να ρισκάρουμε reject
  // λόγω μεγέθους request στο callable.
  static const _maxBytesForModeration = 6 * 1024 * 1024; // 6MB raw

  /// Ελέγχει bytes. Επιστρέφει ModerationResult (approved + racyLevel).
  static Future<ModerationResult> isSafe(Uint8List bytes) async {
    if (!FeatureFlags.contentModerationEnabled) {
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    }
    if (bytes.isEmpty) {
      DebugConfig.log(DebugConfig.moderation,
          'VisionModeration: empty bytes → allow (fail-open)');
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    }
    if (bytes.length > _maxBytesForModeration) {
      DebugConfig.warn(
          'VisionModeration: ${bytes.length} bytes > limit → skip check, allow (fail-open)');
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    }
    try {
      final base64Image = base64Encode(bytes);
      final call = FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('checkImageModeration')
          .call({'image': base64Image});
      unawaited(call.then<void>((_) {},
          onError: (Object e) => DebugConfig.warn(
              'checkImageModeration: late completion after timeout',
              data: e)));
      final result = await call.timeout(_timeout);
      final data = Map<String, dynamic>.from(result.data as Map);
      final approved = data['approved'] as bool? ?? true;
      final levels = data['levels'] as Map?;
      final racyLevel = levels?['racy'] as String? ?? 'VERY_UNLIKELY';
      if (!approved) {
        final reasons = (data['reasons'] as List?)?.join(', ') ?? '';
        DebugConfig.log(DebugConfig.moderation,
            'VisionModeration: REJECTED reasons=$reasons levels=$levels');
      } else if (DebugConfig.moderationVerbose) {
        DebugConfig.log(DebugConfig.moderation,
            'VisionModeration: approved levels=$levels');
      }
      return (approved: approved, racyLevel: racyLevel);
    } on FirebaseFunctionsException catch (e) {
      DebugConfig.warn(
          'VisionModeration: Cloud Function error → allow (fail-open)',
          data: e);
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    } catch (e) {
      DebugConfig.warn(
          'VisionModeration: unexpected error → allow (fail-open)', data: e);
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    }
  }

  /// Profile photos — καλείται από StorageService.uploadAvatar/uploadPhoto.
  static Future<ModerationResult> isProfilePhotoSafe(Uint8List bytes) async {
    if (!FeatureFlags.contentModerationEnabled ||
        !FeatureFlags.autoModerateProfilePhotos) {
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    }
    return isSafe(bytes);
  }

  /// Chat media — καλείται από ChatRepositoryImpl.sendMediaMessage.
  static Future<ModerationResult> isChatMediaSafe(Uint8List bytes) async {
    if (!FeatureFlags.contentModerationEnabled ||
        !FeatureFlags.autoModerateChatMedia) {
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    }
    return isSafe(bytes);
  }

  /// Group avatars — ξεχωριστό granular από το chat media, ώστε το group
  /// avatar moderation να μην εξαρτάται από το `autoModerateChatMedia`.
  static Future<ModerationResult> isGroupAvatarSafe(Uint8List bytes) async {
    if (!FeatureFlags.contentModerationEnabled ||
        !FeatureFlags.autoModerateGroupAvatars) {
      return (approved: true, racyLevel: 'VERY_UNLIKELY');
    }
    return isSafe(bytes);
  }
}