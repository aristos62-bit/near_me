import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/debug/debug_config.dart';
import '../../core/utils/app_exception.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadAvatar(String uid, Uint8List bytes) async {
    DebugConfig.log(DebugConfig.storageUpload, 'uploadAvatar: $uid');
    final ref = _storage.ref().child('avatars/$uid/profile.jpg');
    try {
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      DebugConfig.log(DebugConfig.storageUpload, 'uploadAvatar OK: $uid');
      return url;
    } catch (e, s) {
      DebugConfig.error('uploadAvatar failed', data: e, exception: s);
      throw AppException.storage('uploadAvatar', e, s);
    }
  }

  Future<String> uploadPhoto(String uid, int index, Uint8List bytes) async {
    DebugConfig.log(DebugConfig.storageUpload, 'uploadPhoto: $uid/$index');
    final ref = _storage.ref().child('photos/$uid/$index.jpg');
    try {
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      DebugConfig.log(DebugConfig.storageUpload, 'uploadPhoto OK: $uid/$index');
      return url;
    } catch (e, s) {
      DebugConfig.error('uploadPhoto failed', data: e, exception: s);
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
