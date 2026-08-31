import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import '../data/remote/storage_service.dart';

mixin ProfileStorageMixin {
  StorageService get _storage => StorageService();

  Future<UserProfileTableData?> getProfile();
  Future<void> saveProfile(UserProfileTableData profile);
  Future<void> publish();

  Future<String> saveAvatar(Uint8List bytes) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'saveAvatar');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AppException(
          message: 'No authenticated user', code: 'auth_required');
    }
    if (bytes.isEmpty) {
      throw const AppException(
          message: 'Cannot save empty avatar', code: 'validation_error');
    }
    try {
      final result = await _storage.uploadAvatar(uid, bytes);
      final url = result.url;
      final racyLevel = result.racyLevel;
      final profile = await getProfile();
      if (profile != null) {
        final oldUrl = profile.avatarUrl;
        final oldRacy = profile.avatarRacyLevel;
        try {
          await saveProfile(profile.copyWith(
            avatarUrl: Value(url),
            avatarRacyLevel: Value(racyLevel),
          ));
          if (profile.isPublished) await publish();
        } catch (e) {
          DebugConfig.error('saveAvatar: rollback after save failure', data: e);
          await _storage.deleteAvatar(uid);
          await saveProfile(profile.copyWith(
            avatarUrl: Value(oldUrl),
            avatarRacyLevel: Value(oldRacy),
          ));
          rethrow;
        }
      }
      await DatabaseService.instance.logConsent(uid, 'uploaded_photo', 'avatar');
      DebugConfig.log(DebugConfig.repositoryResult,
          'saveAvatar OK: $uid racyLevel=$racyLevel');
      return url;
    } catch (e, s) {
      DebugConfig.error('saveAvatar failed', data: e, exception: s);
      if (e is AppException) rethrow;
      throw AppException.storage('saveAvatar', e, s);
    }
  }

  Future<void> deleteAvatar() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deleteAvatar');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('deleteAvatar: no authenticated user');
      return;
    }
    try {
      await _storage.deleteAvatar(uid);
      final profile = await getProfile();
      if (profile != null) {
        await saveProfile(profile.copyWith(
          avatarUrl: Value(null),
          avatarRacyLevel: Value(null),
        ));
        if (profile.isPublished) await publish();
      }
      DebugConfig.log(DebugConfig.repositoryResult, 'deleteAvatar OK: $uid');
    } catch (e, s) {
      DebugConfig.error('deleteAvatar failed', data: e, exception: s);
      throw AppException.storage('deleteAvatar', e, s);
    }
  }

  Future<String> savePhoto(Uint8List bytes, int index) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'savePhoto: index=$index');
    if (index < 0) {
      throw const AppException(
          message: 'Invalid photo index', code: 'validation_error');
    }
    if (bytes.isEmpty) {
      throw const AppException(
          message: 'Cannot save empty photo', code: 'validation_error');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AppException(
          message: 'No authenticated user', code: 'auth_required');
    }
    try {
      final result = await _storage.uploadPhoto(uid, index, bytes);
      final url = result.url;
      final racyLevel = result.racyLevel;
      final profile = await getProfile();
      if (profile != null) {
        final urls = List<String>.from(profile.photoUrls ?? []);
        while (urls.length <= index) {
          urls.add('');
        }
        urls[index] = url;
        // Racy levels index-aligned με τα urls — VERY_UNLIKELY placeholder για να μη σπάει alignment (reuse υπάρχοντος convention)
        var racey = List<String>.from(profile.photoRacyLevels ?? []);
        while (racey.length < urls.length) {
          racey.add('VERY_UNLIKELY');
        }
        if (racey.length > urls.length) {
          racey = racey.sublist(0, urls.length);
        }
        racey[index] = racyLevel ?? 'VERY_UNLIKELY';
        // Φιλτράρουμε μαζί: κρατάμε μόνο όπου url != '' (κενά slots από gaps)
        final filteredUrls = <String>[];
        final filteredRacey = <String>[];
        for (var i = 0; i < urls.length; i++) {
          if (urls[i].isNotEmpty) {
            filteredUrls.add(urls[i]);
            filteredRacey.add(i < racey.length ? racey[i] : 'VERY_UNLIKELY');
          }
        }
        await saveProfile(profile.copyWith(
          photoUrls: Value(filteredUrls),
          photoRacyLevels: Value(filteredRacey),
        ));
        if (profile.isPublished) await publish();
      }
      await DatabaseService.instance.logConsent(uid, 'uploaded_photo', 'photo');
      DebugConfig.log(DebugConfig.repositoryResult,
          'savePhoto OK: $uid/$index racyLevel=$racyLevel');
      return url;
    } catch (e, s) {
      DebugConfig.error('savePhoto failed', data: e, exception: s);
      if (e is AppException) rethrow;
      throw AppException.storage('savePhoto', e, s);
    }
  }

  Future<void> deletePhoto(int index) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deletePhoto: index=$index');
    if (index < 0) {
      DebugConfig.warn('deletePhoto: invalid index $index');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('deletePhoto: no authenticated user');
      return;
    }
    try {
      await _storage.deletePhoto(uid, index);
      final profile = await getProfile();
      if (profile != null) {
        final urls = List<String>.from(profile.photoUrls ?? []);
        var racey = List<String>.from(profile.photoRacyLevels ?? []);
        // Legacy fix: ευθυγράμμιση πριν το remove (παλιά bug μπορεί να είχε διαφορετικά lengths)
        while (racey.length < urls.length) {
          racey.add('VERY_UNLIKELY');
        }
        if (racey.length > urls.length) racey = racey.sublist(0, urls.length);
        if (index < urls.length) {
          urls.removeAt(index);
        }
        if (index < racey.length) {
          racey.removeAt(index);
        }
        await saveProfile(profile.copyWith(
          photoUrls: Value(urls),
          photoRacyLevels: Value(racey),
        ));
        if (profile.isPublished) await publish();
      }
      DebugConfig.log(DebugConfig.repositoryResult, 'deletePhoto OK: $uid/$index');
    } catch (e, s) {
      DebugConfig.error('deletePhoto failed', data: e, exception: s);
      throw AppException.storage('deletePhoto', e, s);
    }
  }
}
