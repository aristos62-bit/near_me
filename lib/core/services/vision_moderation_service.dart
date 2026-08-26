import 'dart:typed_data';

import '../config/feature_flags.dart';
import '../debug/debug_config.dart';

/// SPoT — Automated image moderation (SafeSearch / Vision).
///
/// Σήμερα: stub, flag-gated fail-open. Όταν `contentModerationEnabled=false`
/// (default v1) → πάντα `approved` (0 Vision calls, $0, 0 latency).
/// Όταν `true` → εδώ μπαίνει η κλήση Vision (CF callable ή direct).
class VisionModerationService {
  const VisionModerationService._();

  /// Ελέγχει bytes. Επιστρέφει `true` αν επιτρέπεται, `false` αν απορρίπτεται.
  /// Fail-open: timeout/error → επιτρέπεται (server `onFinalize` θα κρίνει).
  static Future<bool> isSafe(Uint8List bytes) async {
    if (!FeatureFlags.contentModerationEnabled) {
      return true;
    }
    if (bytes.isEmpty) {
      DebugConfig.log(DebugConfig.moderation, 'VisionModeration: empty bytes → allow (fail-open)');
      return true;
    }
    // TODO: Vision API call όταν ενεργοποιηθεί το flag
    // final verdict = await _callVision(bytes).timeout(Duration(seconds: 4));
    // if (verdict.isExplicit) return false;
    DebugConfig.log(DebugConfig.moderation, 'VisionModeration: stub check → allow (flag ON but Vision not wired yet)');
    return true;
  }

  /// Για μελλοντικό granular: profile photos
  static Future<bool> isProfilePhotoSafe(Uint8List bytes) async {
    if (!FeatureFlags.contentModerationEnabled || !FeatureFlags.autoModerateProfilePhotos) return true;
    return isSafe(bytes);
  }

  /// Για μελλοντικό granular: chat media
  static Future<bool> isChatMediaSafe(Uint8List bytes) async {
    if (!FeatureFlags.contentModerationEnabled || !FeatureFlags.autoModerateChatMedia) return true;
    return isSafe(bytes);
  }
}
