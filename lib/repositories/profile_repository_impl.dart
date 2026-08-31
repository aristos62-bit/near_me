import 'dart:ui' show PlatformDispatcher;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import '../shared/models/public_profile.dart';
import '../shared/models/user_status.dart';
import '../shared/utils/age_validation.dart';
import 'auth_repository.dart';
import 'profile_repository.dart';
import 'profile_storage_mixin.dart';

// TTL safety net: αν το lastSeen είναι παλιότερο από 2 heartbeats, θεωρείται offline.
// Ίδια τιμή με το προηγούμενο _presenceTTL στο status_provider.dart.
const Duration _presenceTTL = Duration(seconds: 120);

class ProfileRepositoryImpl with ProfileStorageMixin implements ProfileRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  ProfileRepositoryImpl({
    required this._firestore,
    AppDatabase? db,
  }) : _db = db ?? DatabaseService.instance;
  User? get _user => FirebaseAuth.instance.currentUser;

  PublicProfile? _safePublicProfileFromJson(Map<String, dynamic>? data) {
    if (data == null) return null;
    final uid = data['uid'];
    if (uid == null || (uid is String && uid.isEmpty)) return null;
    if (uid is! String) return null;
    try {
      return PublicProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

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
            final pub = _safePublicProfileFromJson(doc.data());
            if (pub == null) {
              DebugConfig.warn('getProfile: skip merge — invalid Firestore data (missing uid)');
            } else if (pub.updatedAt != null && pub.updatedAt!.isAfter(profile.updatedAt)) {
              final firestoreData = doc.data()!;
              final hasAvatarUrl = firestoreData.containsKey('avatarUrl');
              final hasPhotoUrls = firestoreData.containsKey('photoUrls');
              if (hasAvatarUrl || hasPhotoUrls) {
                var updated = profile;
                if (hasAvatarUrl) {
                  updated = updated.copyWith(
                    avatarUrl: Value(pub.avatarUrl),
                    avatarRacyLevel: Value(pub.avatarRacyLevel),
                  );
                }
                if (hasPhotoUrls) {
                  updated = updated.copyWith(
                    photoUrls: Value(pub.photoUrls),
                    photoRacyLevels: Value(pub.photoRacyLevels),
                  );
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
        final pub = _safePublicProfileFromJson(doc.data());
        if (pub == null) {
          DebugConfig.warn('getProfile: skip restore — invalid Firestore data (missing uid)');
          return null;
        }
        final now = DateTime.now();
        final restored = UserProfileTableData(
          id: 0,
          uid: uid,
          nickname: pub.nickname ?? '',
          bio: pub.bio,
          birthYear: pub.age != null && pub.age! >= 18
              ? now.year - pub.age!
              : null,
          gender: pub.gender,
          interests: pub.interests,
          occupations: pub.occupations,
          lookingFor: pub.lookingFor,
          city: pub.city,
          country: pub.country,
          avatarUrl: pub.avatarUrl,
          photoUrls: pub.photoUrls,
          avatarRacyLevel: pub.avatarRacyLevel,
          photoRacyLevels: pub.photoRacyLevels,
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
        await _ensurePrivacySettings(uid, sourceProfile: restored);
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
    if (!AgeValidation.isPlausibleBirthYear(profile.birthYear) ||
        !AgeValidation.isAdultBirthYear(profile.birthYear)) {
      DebugConfig.error('saveProfile REJECTED invalid birthYear=${profile.birthYear}');
      throw const AppException(
          message: 'Birth year is required and must be 18+',
          code: 'validation_error');
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
        await _ensurePrivacySettings(uid, sourceProfile: data);
        DebugConfig.log(DebugConfig.databaseLocal, 'saveProfile inserted');
      }
      DebugConfig.log(DebugConfig.repositoryResult, 'saveProfile OK');
    } catch (e, s) {
      DebugConfig.error('saveProfile failed', data: e, exception: s);
      throw AppException.database('saveProfile', e, s);
    }
  }

  Future<void> _ensurePrivacySettings(String uid, {UserProfileTableData? sourceProfile}) async {
    DebugConfig.log(DebugConfig.databaseLocal, '_ensurePrivacySettings: checking for $uid');
    try {
      final existing = await (_db.select(_db.privacySettingsTable)
        ..where((t) => t.uid.equals(uid))).getSingleOrNull();
      if (existing != null) {
        DebugConfig.log(DebugConfig.databaseLocal, '_ensurePrivacySettings: already exist for $uid');
        return;
      }
      await _db.into(_db.privacySettingsTable).insert(
        PrivacySettingsTableCompanion.insert(
          uid: Value(uid),
          // Seed από το UserProfileTable αν υπάρχει (π.χ. restore σε νέα
          // συσκευή από Firestore) — αποφεύγει να επαναφέρουμε στο false/false
          // μια ρύθμιση που ο χρήστης είχε ήδη κάνει.
          allowVideoCall: sourceProfile != null
              ? Value(sourceProfile.allowVideoCall)
              : const Value.absent(),
          allowDirectChat: sourceProfile != null
              ? Value(sourceProfile.allowDirectChat)
              : const Value.absent(),
        ),
      );
      DebugConfig.log(DebugConfig.databaseLocal,
          '_ensurePrivacySettings: inserted for $uid'
              '${sourceProfile != null ? " (seeded allowVideoCall=${sourceProfile.allowVideoCall}, allowDirectChat=${sourceProfile.allowDirectChat})" : " (defaults)"}');
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

    // Sync στο Firestore SPoT — η computeGeoHash function το διαβάζει
    // server-side. Best-effort: δεν σπάει το topical save αν αποτύχει,
    // ίδιο σκεπτικό με το deleteAccount (μη-κρίσιμο cleanup βήμα).
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('privacy')
          .doc('settings')
          .set({'geoPrecision': settings.geoPrecision});
      DebugConfig.log(DebugConfig.firestoreWrite,
          'savePrivacySettings: geoPrecision synced to Firestore: ${settings.geoPrecision}');
    } catch (e, s) {
      DebugConfig.error(
          'savePrivacySettings: Firestore geoPrecision sync failed (non-fatal)',
          data: e, exception: s);
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
      if (!AgeValidation.isPlausibleBirthYear(profile.birthYear) ||
          !AgeValidation.isAdultBirthYear(profile.birthYear)) {
        DebugConfig.error('publish REJECTED invalid birthYear=${profile.birthYear}');
        throw const AppException(
            message: 'Cannot publish: birth year is required and must be 18+',
            code: 'validation_error');
      }
      await _ensurePrivacySettings(uid, sourceProfile: profile);
      final privacy = await getPrivacySettings();

      // Το geoHash δεν υπολογίζεται πλέον εδώ — server-side authoritative
      // μέσω computeGeoHash (μετά το set παρακάτω), βάσει του geoPrecision
      // στο /users/{uid}/privacy/settings (Firestore SPoT).
      final hasLocation =
          profile.latitudeExact != null && profile.longitudeExact != null;

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
        avatarUrl: privacy?.showAvatar == true ? profile.avatarUrl : null,
        photoUrls: privacy?.showPhotos == true ? profile.photoUrls : null,
        avatarRacyLevel:
            privacy?.showAvatar == true ? profile.avatarRacyLevel : null,
        photoRacyLevels:
            privacy?.showPhotos == true ? profile.photoRacyLevels : null,
        email: privacy?.showEmail == true ? profile.email : null,
        phone: privacy?.showPhone == true ? profile.phone : null,
        allowVideoCall: privacy?.allowVideoCall ?? false,
        allowDirectChat: privacy?.allowDirectChat ?? false,
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
      if (publicProfile.nickname != null && publicProfile.nickname!.isNotEmpty) {
        json['nicknameLowercase'] = publicProfile.nickname!.toLowerCase().trim();
      }
      DebugConfig.log(DebugConfig.firestoreWrite,
          'publish JSON: nicknameLowercase=${json['nicknameLowercase']}, '
              'city=${json['city']}, country=${json['country']}, '
              'isManualLocation=${json['isManualLocation']}, '
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
          final existingData = existingDoc.data();
          final existingIsOnline = existingData?['isOnline'];
          if (existingIsOnline != null) {
            json['isOnline'] = existingIsOnline as bool;
          }
          // Preserve το υπάρχον geoHash (ίδιο idiom με isOnline παραπάνω) —
          // αποφεύγει flicker/κενό στο discovery search μέχρι να τρέξει η
          // computeGeoHash function παρακάτω.
          final existingGeoHash = existingData?['geoHash'];
          if (existingGeoHash != null) {
            json['geoHash'] = existingGeoHash as String;
          }
          // Preserve το ενεργό SOS helpRequest (sos.md §9.2): κρατάμε το πεδίο
          // ΜΟΝΟ όσο ο χρήστης παραμένει verified (canUserCommunicate) — αλλιώς
          // ο targeted validation rule θα απέρριπτε το publish (απαιτεί isVerified
          // όταν το helpRequest γράφεται στο payload). N1.
          final existingHelpRequest = existingData?['helpRequest'];
          if (existingHelpRequest != null &&
              AuthRepository.canUserCommunicate(_user)) {
            json['helpRequest'] = existingHelpRequest;
            DebugConfig.log(DebugConfig.helpRequest,
                'publish: preserved active helpRequest (uid=$uid, verified)');
          }
        }
      } catch (e) {
        DebugConfig.warn('publish: failed to read existing isOnline/geoHash', data: e);
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('public')
          .doc('profile')
          .set(json);
      if (DebugConfig.debugMode) {
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
      }
      await saveProfile(profile.copyWith(isPublished: true));
      await _db.logConsent(uid, 'publish', 'profile');
      DebugConfig.log(DebugConfig.firestoreWrite,
          'publish: $uid, city=${profile.city}, country=${profile.country}, '
              'lat=${profile.latitudeExact}, lng=${profile.longitudeExact}, '
              'isManualLocation=${profile.latitudeExact == null && profile.longitudeExact == null}');

      // Server-side authoritative geoHash. Best-effort: αν αποτύχει, το
      // preserve pattern παραπάνω κρατάει το προηγούμενο geoHash — δεν
      // σπάει το publish (ίδιο σκεπτικό με deleteAccount CF call).
      if (hasLocation) {
        try {
          final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('computeGeoHash')
              .call({
            'latitude': profile.latitudeExact,
            'longitude': profile.longitudeExact,
          });
          DebugConfig.log(DebugConfig.cloudFunctions,
              'publish: CF computeGeoHash success: ${result.data}');
        } catch (e) {
          DebugConfig.warn(
              'publish: CF computeGeoHash failed, keeping previous geoHash',
              data: e);
        }
      }
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

  /// Ενεργοποιεί/απενεργοποιεί το SOS (helpRequest) στο public doc.
  /// Ενεργό → update του nested `helpRequest` (updatedAt σε UTC ISO8601 —
  /// βλ. sos.md §5.2). Απενεργοποίηση → `FieldValue.delete()` για καθαρό
  /// καθαρισμό (δεν μένει stale object). Owner write, 1 write.
  @override
  Future<void> setHelpRequest({
    required bool active,
    String? message,
    double? radiusKm,
  }) async {
    DebugConfig.log(DebugConfig.helpRequest,
        'setHelpRequest: active=$active${message != null ? ', message="$message"' : ''}${radiusKm != null ? ', radiusKm=$radiusKm' : ''}');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AppException(
          message: 'No authenticated user', code: 'auth_required');
    }
    if (active && message != null && message.length > 80) {
      DebugConfig.warn(
          'setHelpRequest: message too long (${message.length} chars)');
      throw const AppException(
          message: 'Help message too long', code: 'help/message-too-long');
    }
    try {
      if (active) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('public')
            .doc('profile')
            .update({
          'helpRequest': {
            'active': true,
            'message': message ?? '',
            'radiusKm': radiusKm ?? 10.0,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }
        });
        await _db.logConsent(uid, 'help_request_activate', 'public');
        DebugConfig.log(DebugConfig.helpRequest,
            'setHelpRequest: SOS ACTIVATED uid=$uid radiusKm=${radiusKm ?? 10.0} message="$message"');
      } else {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('public')
            .doc('profile')
            .update({
          'helpRequest': FieldValue.delete(),
        });
        await _db.logConsent(uid, 'help_request_deactivate', 'public');
        DebugConfig.log(
            DebugConfig.helpRequest, 'setHelpRequest: SOS DEACTIVATED uid=$uid');
      }
      DebugConfig.log(DebugConfig.firestoreWrite,
          'setHelpRequest: uid=$uid ${active ? "activate" : "deactivate"} write OK');
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        DebugConfig.warn(
            'setHelpRequest: public profile doc missing (not-found)',
            data: e.code);
        throw const AppException(
            message: 'Published profile not found', code: 'help/not-found');
      }
      DebugConfig.error('setHelpRequest failed (FirebaseException)', data: e);
      throw AppException.firestore('setHelpRequest', e);
    } catch (e, s) {
      DebugConfig.error('setHelpRequest failed', data: e, exception: s);
      throw AppException.firestore('setHelpRequest', e, s);
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
  Future<UserProfileTableData?> syncLocation(double lat, double lng, {String? city, String? country}) async {
    DebugConfig.log(DebugConfig.repositoryCall,
        'syncLocation: lat=$lat, lng=$lng${city != null ? ', city=$city' : ''}${country != null ? ', country=$country' : ''}');
    final uid = _user?.uid;
    if (uid == null || uid.isEmpty) {
      DebugConfig.warn('syncLocation: no authenticated user');
      return null;
    }
    try {
      final profile = await getProfile();
      if (profile == null) {
        DebugConfig.warn('syncLocation: no profile found');
        return null;
      }
      var update = profile.copyWith(
        latitudeExact: Value(lat),
        longitudeExact: Value(lng),
      );
      if (city != null) {
        update = update.copyWith(city: Value(city));
      }
      if (country != null) {
        update = update.copyWith(country: Value(country));
      }
      await saveProfile(update);
      DebugConfig.log(DebugConfig.databaseLocal,
          'syncLocation: saved lat=$lat, lng=$lng${city != null ? ', city=$city' : ''}${country != null ? ', country=$country' : ''}');
      return profile;
    } catch (e, s) {
      DebugConfig.error('syncLocation failed', data: e, exception: s);
      throw AppException.database('syncLocation', e, s);
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
      final pub = _safePublicProfileFromJson(doc.data());
      if (pub == null) {
        DebugConfig.warn('getPublicProfile: invalid Firestore data — treating as not found');
      }
      return pub;
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
      // Παλιά docs μπορεί να μην έχουν `uid` — αντλούμε από το doc path
      // (users/{uid}/public/profile), ίδιο pattern με το firestore_search_repository.
      data['uid'] ??= snapshot.reference.parent.parent?.id;
      try {
        return PublicProfile.fromJson(data);
      } catch (e, s) {
        DebugConfig.error('streamPublicProfile parse error', data: e, exception: s);
        return null;
      }
    });
  }

  @override
  Stream<UserStatus> streamUserStatus(String uid) {
    if (uid.isEmpty) {
      DebugConfig.warn('streamUserStatus: empty uid');
      return Stream.value(const UserStatus(isOnline: false));
    }
    return _firestore
        .doc('users/$uid/status/status')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return const UserStatus(isOnline: false);
      final data = snap.data()!;
      final isOnline = data['isOnline'] as bool? ?? false;
      final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();

      // TTL safety net: αν το lastSeen είναι παλιότερο από 2 heartbeats, θεωρείται offline
      final effectiveOnline = isOnline &&
          lastSeen != null &&
          DateTime.now().difference(lastSeen) < _presenceTTL;

      DebugConfig.log(DebugConfig.presence,
          'streamUserStatus uid=$uid isOnline=$isOnline lastSeen=$lastSeen effective=$effectiveOnline');

      return UserStatus(
        isOnline: effectiveOnline,
        lastSeen: lastSeen,
      );
    }).handleError((e) {
      DebugConfig.log(DebugConfig.presence,
          'streamUserStatus: uid=$uid error=$e (non-fatal)');
      return const UserStatus(isOnline: false);
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
