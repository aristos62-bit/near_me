import 'dart:ui' show PlatformDispatcher;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/geohash_utils.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import '../shared/models/public_profile.dart';
import 'profile_repository.dart';
import 'profile_storage_mixin.dart';

class ProfileRepositoryImpl with ProfileStorageMixin implements ProfileRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  ProfileRepositoryImpl({
    required this._firestore,
    AppDatabase? db,
  }) : _db = db ?? DatabaseService.instance;
  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  Future<UserProfileTableData?> getProfile() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'getProfile');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('getProfile: no authenticated user');
      return null;
    }
    try {
      final profile = await (_db.select(_db.userProfileTable)
        ..where((t) => t.uid.equals(uid))).getSingleOrNull();
      if (profile != null) {
        DebugConfig.log(DebugConfig.repositoryResult,
            'getProfile: ${profile.nickname ?? "(unnamed)"} (local)');
        try {
          final doc = await _firestore
              .collection('users')
              .doc(uid)
              .collection('public')
              .doc('profile')
              .get();
          if (doc.exists) {
            final pub = PublicProfile.fromJson(doc.data()!);
            if (pub.updatedAt != null && pub.updatedAt!.isAfter(profile.updatedAt)) {
              final firestoreData = doc.data()!;
              final hasAvatarUrl = firestoreData.containsKey('avatarUrl');
              final hasPhotoUrls = firestoreData.containsKey('photoUrls');
              if (hasAvatarUrl || hasPhotoUrls) {
                var updated = profile;
                if (hasAvatarUrl) {
                  updated = updated.copyWith(avatarUrl: Value(pub.avatarUrl));
                }
                if (hasPhotoUrls) {
                  updated = updated.copyWith(photoUrls: Value(pub.photoUrls));
                }
                await saveProfile(updated);
                DebugConfig.log(DebugConfig.repositoryResult,
                    'getProfile: merged avatarUrl/photoUrls from Firestore');
                return updated;
              }
            }
          }
        } catch (e) {
          DebugConfig.warn('getProfile: Firestore merge check failed', data: e);
        }
        return profile;
      }
      try {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('public')
            .doc('profile')
            .get();
        if (!doc.exists) {
          DebugConfig.log(
              DebugConfig.repositoryResult, 'getProfile: null (no local, no firestore)');
          return null;
        }
        final pub = PublicProfile.fromJson(doc.data()!);
        final now = DateTime.now();
        final restored = UserProfileTableData(
          id: 0,
          uid: uid,
          nickname: pub.nickname ?? '',
          bio: pub.bio,
          birthYear: pub.age != null ? now.year - pub.age! : null,
          gender: pub.gender,
          interests: pub.interests,
          occupations: pub.occupations,
          lookingFor: pub.lookingFor,
          city: pub.city,
          country: pub.country,
          avatarUrl: pub.avatarUrl,
          photoUrls: pub.photoUrls,
          email: pub.email,
          phone: pub.phone,
          allowVideoCall: pub.allowVideoCall,
          allowDirectChat: pub.allowDirectChat,
          isPublished: true,
          createdAt: now,
          updatedAt: now,
        );
        await _db.into(_db.userProfileTable).insert(
              restored.toCompanion(true).copyWith(id: const Value.absent()),
            );
        await _ensurePrivacySettings(uid);
        DebugConfig.log(DebugConfig.repositoryResult,
            'getProfile: restored from firestore: ${pub.nickname ?? "(unnamed)"}');
        DebugConfig.log(DebugConfig.repositoryResult,
            'getProfile: avatarUrl=${pub.avatarUrl != null && pub.avatarUrl!.isNotEmpty ? "present (${pub.avatarUrl!.length} chars)" : "null or empty"}');
        return restored;
      } catch (e2) {
        DebugConfig.warn('getProfile: firestore fallback failed', data: e2);
        return null;
      }
    } catch (e, s) {
      DebugConfig.error('getProfile: database error', data: e, exception: s);
      throw AppException.database('getProfile', e, s);
    }
  }

  @override
  Future<void> saveProfile(UserProfileTableData profile) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'saveProfile');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AppException(
          message: 'No authenticated user', code: 'auth_required');
    }
    try {
      final now = DateTime.now();
      var data = profile.copyWith(uid: Value(uid), updatedAt: now);
      final existing = await (_db.select(_db.userProfileTable)
        ..where((t) => t.uid.equals(uid))).getSingleOrNull();
      if (existing != null) {
        data = data.copyWith(id: existing.id, createdAt: existing.createdAt);
        await _db.update(_db.userProfileTable).replace(data);
        DebugConfig.log(DebugConfig.databaseLocal, 'saveProfile updated: id=${existing.id}');
      } else {
        data = data.copyWith(createdAt: now);
        await _db.into(_db.userProfileTable)
            .insert(data.toCompanion(true).copyWith(id: const Value.absent()));
        await _ensurePrivacySettings(uid);
        DebugConfig.log(DebugConfig.databaseLocal, 'saveProfile inserted');
      }
      DebugConfig.log(DebugConfig.repositoryResult, 'saveProfile OK');
    } catch (e, s) {
      DebugConfig.error('saveProfile failed', data: e, exception: s);
      throw AppException.database('saveProfile', e, s);
    }
  }

  Future<void> _ensurePrivacySettings(String uid) async {
    DebugConfig.log(DebugConfig.databaseLocal, '_ensurePrivacySettings: checking for $uid');
    try {
      final existing = await (_db.select(_db.privacySettingsTable)
        ..where((t) => t.uid.equals(uid))).getSingleOrNull();
      if (existing != null) {
        DebugConfig.log(DebugConfig.databaseLocal, '_ensurePrivacySettings: already exist for $uid');
        return;
      }
      await _db.into(_db.privacySettingsTable).insert(
        PrivacySettingsTableCompanion.insert(uid: Value(uid)),
      );
      DebugConfig.log(DebugConfig.databaseLocal, '_ensurePrivacySettings: inserted defaults for $uid');
    } catch (e, s) {
      DebugConfig.error('_ensurePrivacySettings failed', data: e, exception: s);
    }
  }

  @override
  Future<void> deleteProfile() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'deleteProfile');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('deleteProfile: no authenticated user');
      return;
    }
    try {
      await (_db.delete(_db.userProfileTable)
        ..where((t) => t.uid.equals(uid))).go();
      DebugConfig.log(DebugConfig.databaseLocal, 'deleteProfile deleted: $uid');
    } catch (e, s) {
      DebugConfig.error('deleteProfile failed', data: e, exception: s);
      throw AppException.database('deleteProfile', e, s);
    }
  }

  @override
  Future<PrivacySettingsTableData?> getPrivacySettings() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'getPrivacySettings');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('getPrivacySettings: no authenticated user');
      return null;
    }
    try {
      final settings = await (_db.select(_db.privacySettingsTable)
        ..where((t) => t.uid.equals(uid))).getSingleOrNull();
      DebugConfig.log(
          DebugConfig.repositoryResult, 'getPrivacySettings: ${settings != null}');
      return settings;
    } catch (e, s) {
      DebugConfig.error('getPrivacySettings failed', data: e, exception: s);
      throw AppException.database('getPrivacySettings', e, s);
    }
  }

  @override
  Future<void> savePrivacySettings(PrivacySettingsTableData settings) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'savePrivacySettings');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AppException(
          message: 'No authenticated user', code: 'auth_required');
    }
    try {
      final data = settings.copyWith(uid: Value(uid));
      final existing = await (_db.select(_db.privacySettingsTable)
        ..where((t) => t.uid.equals(uid))).getSingleOrNull();
      if (existing != null) {
        await _db.update(_db.privacySettingsTable).replace(data.copyWith(id: existing.id));
        DebugConfig.log(DebugConfig.databaseLocal, 'savePrivacySettings updated');
      } else {
        await _db.into(_db.privacySettingsTable).insert(
              data.toCompanion(true).copyWith(id: const Value.absent()),
            );
        DebugConfig.log(DebugConfig.databaseLocal, 'savePrivacySettings inserted');
      }
      DebugConfig.log(DebugConfig.repositoryResult, 'savePrivacySettings OK');
    } catch (e, s) {
      DebugConfig.error('savePrivacySettings failed', data: e, exception: s);
      throw AppException.database('savePrivacySettings', e, s);
    }
  }

  @override
  Future<void> publish() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'publish');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AppException(
          message: 'No authenticated user', code: 'auth_required');
    }
    try {
      final profile = await getProfile();
      if (profile == null) {
        throw const AppException(
            message: 'Cannot publish: no profile exists',
            code: 'validation_error');
      }
      await _ensurePrivacySettings(uid);
      final privacy = await getPrivacySettings();

      String? geoHash;
      if (privacy != null &&
          privacy.geoPrecision != 'hidden' &&
          profile.latitudeExact != null &&
          profile.longitudeExact != null) {
        final precision =
            GeoHashUtils.precisionFromSetting(privacy.geoPrecision);
        if (precision > 0) {
          geoHash = GeoHashUtils.encode(
            profile.latitudeExact!,
            profile.longitudeExact!,
            precision: precision,
          );
        }
      }

      final now = DateTime.now();
      final publicProfile = PublicProfile(
        uid: uid,
        nickname: privacy?.showNickname == true ? profile.nickname : null,
        age: privacy?.showAge == true && profile.birthYear != null
            ? now.year - profile.birthYear!
            : null,
        gender: privacy?.showGender == true ? profile.gender : null,
        city: privacy?.showCity == true ? profile.city : null,
        country: privacy?.showCountry == true ? profile.country : null,
        interests: privacy?.showInterests == true ? profile.interests : null,
        occupations: privacy?.showOccupation == true ? profile.occupations : null,
        lookingFor: privacy?.showLookingFor == true ? profile.lookingFor : null,
        bio: privacy?.showBio == true ? profile.bio : null,
        avatarUrl: privacy?.showPhotos == true ? profile.avatarUrl : null,
        photoUrls: privacy?.showPhotos == true ? profile.photoUrls : null,
        email: privacy?.showEmail == true ? profile.email : null,
        phone: privacy?.showPhone == true ? profile.phone : null,
        allowVideoCall: profile.allowVideoCall,
        allowDirectChat: profile.allowDirectChat,
        geoHash: geoHash,
        isManualLocation: profile.latitudeExact == null && profile.longitudeExact == null,
        isVisible: true,
        lang: PlatformDispatcher.instance.locale.languageCode == 'el' ? 'el' : 'en',
        updatedAt: now,
      );

      final json = publicProfile.toJson()
        ..removeWhere((_, v) => v == null)
        ..remove('isOnline');

// Normalized fields για case-insensitive city/country search
      if (publicProfile.city != null && publicProfile.city!.isNotEmpty) {
        json['cityNormalized'] = publicProfile.city!.toLowerCase().trim();
      }
      if (publicProfile.country != null && publicProfile.country!.isNotEmpty) {
        json['countryNormalized'] = publicProfile.country!.toLowerCase().trim();
      }
      DebugConfig.log(DebugConfig.firestoreWrite,
          'publish JSON: city=${json['city']}, country=${json['country']}, '
          'geoHash=${json['geoHash']}, isManualLocation=${json['isManualLocation']}, '
          'showPhotos=${privacy?.showPhotos}, showCity=${privacy?.showCity}, showCountry=${privacy?.showCountry}, '
          'avatarUrl=${json['avatarUrl'] != null ? "present (${json['avatarUrl'].toString().length} chars)" : "absent"}');
      try {
        final existingDoc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('public')
            .doc('profile')
            .get();
        if (existingDoc.exists) {
          final existingIsOnline = existingDoc.data()?['isOnline'];
          if (existingIsOnline != null) {
            json['isOnline'] = existingIsOnline as bool;
          }
        }
      } catch (e) {
        DebugConfig.warn('publish: failed to read existing isOnline', data: e);
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('public')
          .doc('profile')
          .set(json);
      try {
        final verifyDoc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('public')
            .doc('profile')
            .get();
        if (verifyDoc.exists) {
          final rawData = verifyDoc.data()!;
          DebugConfig.log(DebugConfig.firestoreWrite,
              'publish VERIFY doc after set: isVisible=${rawData['isVisible']}, '
              'city="${rawData['city']}", country="${rawData['country']}", '
              'geoHash="${rawData['geoHash']}", isManualLocation=${rawData['isManualLocation']}, '
              'isOnline=${rawData['isOnline']}, keys=${rawData.keys.join(", ")}');
        } else {
          DebugConfig.warn('publish VERIFY: doc not found after set');
        }
      } catch (e) {
        DebugConfig.warn('publish VERIFY: failed to read back', data: e);
      }
      await saveProfile(profile.copyWith(isPublished: true));
      await _db.logConsent(uid, 'publish', 'profile');
      DebugConfig.log(DebugConfig.firestoreWrite,
          'publish: $uid, city=${profile.city}, country=${profile.country}, '
          'lat=${profile.latitudeExact}, lng=${profile.longitudeExact}, '
          'geoHash=$geoHash, isManualLocation=${profile.latitudeExact == null && profile.longitudeExact == null}');
    } catch (e, s) {
      DebugConfig.error('publish failed', data: e, exception: s);
      if (e is AppException) rethrow;
      throw AppException.firestore('publish', e, s);
    }
  }

  @override
  Future<void> unpublish() async {
    DebugConfig.log(DebugConfig.repositoryCall, 'unpublish');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('unpublish: no authenticated user');
      return;
    }
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('public')
          .doc('profile')
          .delete();
      final profile = await getProfile();
      if (profile != null) {
        await saveProfile(profile.copyWith(isPublished: false));
      }
      await _db.logConsent(uid, 'unpublish', 'profile');
      DebugConfig.log(DebugConfig.firestoreWrite, 'unpublish: $uid');
    } catch (e, s) {
      DebugConfig.error('unpublish failed', data: e, exception: s);
      throw AppException.firestore('unpublish', e, s);
    }
  }

  @override
  Future<bool> get isPublished async {
    DebugConfig.log(DebugConfig.repositoryCall, 'isPublished');
    try {
      final profile = await getProfile();
      final result = profile?.isPublished ?? false;
      DebugConfig.log(DebugConfig.repositoryResult, 'isPublished: $result');
      return result;
    } catch (e, s) {
      DebugConfig.error('isPublished check failed', data: e, exception: s);
      return false;
    }
  }

  @override
  Stream<PublicProfile?> publicProfileStream() {
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('publicProfileStream: no authenticated user');
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('public')
        .doc('profile')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        DebugConfig.log(DebugConfig.firestoreStream, 'publicProfileStream: doc deleted');
        return null;
      }
      final data = snapshot.data();
      if (data == null) {
        DebugConfig.warn('publicProfileStream: data() returned null');
        return null;
      }
      try {
        return PublicProfile.fromJson(data);
      } catch (e, s) {
        DebugConfig.error('publicProfileStream parse error', data: e, exception: s);
        return null;
      }
    });
  }

  @override
  Future<PublicProfile?> getPublicProfile(String uid) async {
    DebugConfig.log(DebugConfig.repositoryCall, 'getPublicProfile: $uid');
    if (uid.isEmpty) {
      DebugConfig.warn('getPublicProfile: empty uid');
      return null;
    }
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('public')
          .doc('profile')
          .get();
      if (!doc.exists) {
        DebugConfig.log(DebugConfig.repositoryResult, 'getPublicProfile: not found');
        return null;
      }
      return PublicProfile.fromJson(doc.data()!);
    } catch (e, s) {
      DebugConfig.error('getPublicProfile failed', data: e, exception: s);
      throw AppException.firestore('getPublicProfile', e, s);
    }
  }

  @override
  Stream<PublicProfile?> streamPublicProfile(String uid) {
    DebugConfig.log(DebugConfig.firestoreStream, 'streamPublicProfile: $uid');
    if (uid.isEmpty) {
      DebugConfig.warn('streamPublicProfile: empty uid');
      return const Stream.empty();
    }
    if (_user == null) {
      DebugConfig.warn('streamPublicProfile: no authenticated user');
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('public')
        .doc('profile')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) {
        DebugConfig.warn('streamPublicProfile: data() returned null');
        return null;
      }
      try {
        return PublicProfile.fromJson(data);
      } catch (e, s) {
        DebugConfig.error('streamPublicProfile parse error', data: e, exception: s);
        return null;
      }
    });
  }

  @override
  Stream<UserProfileTableData?> streamProfile() {
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('streamProfile: no authenticated user');
      return const Stream.empty();
    }
    DebugConfig.log(DebugConfig.databaseLocalStream, 'streamProfile started: $uid');
    return (_db.select(_db.userProfileTable)
      ..where((t) => t.uid.equals(uid))).watchSingleOrNull().handleError((e, s) {
      DebugConfig.error('streamProfile: watch error', data: e, exception: s);
      return null;
    });
  }
}
