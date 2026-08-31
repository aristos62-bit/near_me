import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/config/feature_flags.dart';
import '../../core/debug/debug_config.dart';
import '../../core/services/vision_moderation_service.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/storage_helpers.dart';

typedef StorageUploadResult = ({String url, String? racyLevel});

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<StorageUploadResult> uploadAvatar(String uid, Uint8List bytes) async {
    DebugConfig.log(DebugConfig.storageUpload, 'uploadAvatar: $uid');
    String? racyLevel;
    if (FeatureFlags.contentModerationEnabled && FeatureFlags.autoModerateProfilePhotos) {
      final res = await VisionModerationService.isProfilePhotoSafe(bytes);
      if (!res.approved) {
        DebugConfig.log(DebugConfig.moderation, 'uploadAvatar blocked by moderation: $uid');
        throw AppException(message: 'Moderation rejected avatar', code: 'moderation/blocked-explicit');
      }
      racyLevel = res.racyLevel;
    }
    final ref = _storage.ref().child('avatars/$uid/profile.jpg');
    try {
      await StorageHelpers.uploadBytesWithTimeout(ref, bytes,
          contentType: 'image/jpeg', type: 'avatar');
      final url = await StorageHelpers.downloadUrlWithTimeout(ref);
      DebugConfig.log(DebugConfig.storageUpload, 'uploadAvatar OK: $uid racyLevel=$racyLevel');
      return (url: url, racyLevel: racyLevel);
    } catch (e, s) {
      DebugConfig.error('uploadAvatar failed', data: e, exception: s,
          reportToCrashlytics: true);
      throw AppException.storage('uploadAvatar', e, s);
    }
  }

  Future<StorageUploadResult> uploadPhoto(String uid, int index, Uint8List bytes) async {
    DebugConfig.log(DebugConfig.storageUpload, 'uploadPhoto: $uid/$index');
    String? racyLevel;
    if (FeatureFlags.contentModerationEnabled && FeatureFlags.autoModerateProfilePhotos) {
      final res = await VisionModerationService.isProfilePhotoSafe(bytes);
      if (!res.approved) {
        DebugConfig.log(DebugConfig.moderation, 'uploadPhoto blocked by moderation: $uid/$index');
        throw AppException(message: 'Moderation rejected photo', code: 'moderation/blocked-explicit');
      }
      racyLevel = res.racyLevel;
    }
    final ref = _storage.ref().child('photos/$uid/$index.jpg');
    try {
      await StorageHelpers.uploadBytesWithTimeout(ref, bytes,
          contentType: 'image/jpeg', type: 'photo');
      final url = await StorageHelpers.downloadUrlWithTimeout(ref);
      DebugConfig.log(DebugConfig.storageUpload, 'uploadPhoto OK: $uid/$index racyLevel=$racyLevel');
      return (url: url, racyLevel: racyLevel);
    } catch (e, s) {
      DebugConfig.error('uploadPhoto failed', data: e, exception: s,
          reportToCrashlytics: true);
      throw AppException.storage('uploadPhoto', e, s);
    }
  }

  Future<void> deleteAvatar(String uid) async {
    DebugConfig.log(DebugConfig.storageUpload, 'deleteAvatar: $uid');
    final ref = _storage.ref().child('avatars/$uid/profile.jpg');
    try {
      await ref.delete();
      DebugConfig.log(DebugConfig.storageUpload, 'deleteAvatar OK: $uid');
    } catch (e) {
      DebugConfig.warn('deleteAvatar failed (may not exist)', data: e);
    }
  }

  Future<void> deletePhoto(String uid, int index) async {
    DebugConfig.log(DebugConfig.storageUpload, 'deletePhoto: $uid/$index');
    final ref = _storage.ref().child('photos/$uid/$index.jpg');
    try {
      await ref.delete();
      DebugConfig.log(DebugConfig.storageUpload, 'deletePhoto OK: $uid/$index');
    } catch (e) {
      DebugConfig.warn('deletePhoto failed (may not exist)', data: e);
    }
  }

  Future<void> deleteAllUserFiles(String uid) async {
    DebugConfig.log(DebugConfig.storageUpload, 'deleteAllUserFiles: $uid');
    try {
      await deleteAvatar(uid);
      for (var i = 0; i < 5; i++) {
        await deletePhoto(uid, i);
      }
      DebugConfig.log(DebugConfig.storageUpload, 'deleteAllUserFiles OK: $uid');
    } catch (e) {
      DebugConfig.warn('deleteAllUserFiles failed', data: e);
    }
  }
}
