import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_me/core/utils/geohash_utils.dart';
import 'package:near_me/data/local/database.dart';

/// [SPoT] Κατασκευή εγγράφου για `users/{uid}/public/profile` — isomorphic
/// με όσα πεδία διαβάζει ο `PublicProfile.fromJson` συν τα normalized fields
/// που ζητούν τα queries (`cityNormalized`/`countryNormalized`).
///
/// ΕΝΑ SPoT για ΟΛΑ τα repository tests: μην το διασπάς σε fixtures εδώ κι εκεί.
Map<String, dynamic> publicProfileDoc({
  required String uid,
  String? nickname,
  int? age,
  String? gender,
  String? city,
  String? country,
  String? geoHash,
  List<String>? interests,
  String? lookingFor,
  bool allowVideoCall = false,
  bool allowDirectChat = false,
  bool isVisible = true,
  bool isOnline = false,
}) {
  return {
    'uid': uid,
    'nickname': ?nickname,
    'age': ?age,
    'gender': ?gender,
    'city': ?city,
    'cityNormalized': ?city?.toLowerCase(),
    'country': ?country,
    'countryNormalized': ?country?.toLowerCase(),
    'geoHash': ?geoHash,
    'interests': ?interests,
    'lookingFor': ?lookingFor,
    'allowVideoCall': allowVideoCall,
    'allowDirectChat': allowDirectChat,
    'isVisible': isVisible,
    'isOnline': isOnline,
  };
}

/// [SPoT] Seed ενός public profile στο fake Firestore (`users/{uid}/public/profile`).
Future<void> seedPublicProfile(
    FakeFirebaseFirestore firestore, Map<String, dynamic> doc) {
  return firestore
      .collection('users')
      .doc(doc['uid'] as String)
      .collection('public')
      .doc('profile')
      .set(doc);
}

/// [SPoT] Seed πολλών profiles με ένα call.
Future<void> seedPublicProfiles(
    FakeFirebaseFirestore firestore, Iterable<Map<String, dynamic>> docs) async {
  for (final d in docs) {
    await seedPublicProfile(firestore, d);
  }
}

/// [SPoT] Geohash (cell) που σίγουρα μπαίνει σε επιτυχημένο geo-search για
/// ακτίνα [radiusKm]: χρησιμοποιεί την ΙΔΙΑ adaptive precision με τον
/// `FirestoreSearchRepository` (ώστε τα fixtures να μην εξαρτώνται από μαγικά νούμερα).
String geoCell(double lat, double lng, double radiusKm) =>
    GeoHashUtils.encode(
      lat,
      lng,
      precision: GeoHashUtils.searchPrecision(radiusKm, lat),
    );

/// [SPoT] Fixture UserProfileTableData για repository tests (drift).
/// Όλα τα fields optional με defaults σχεδιασμένα για valid save/publish
/// (birthYear 1995 → 18+, δεν απαιτείται lat/lng → manual location).
UserProfileTableData profileTableData({
  int id = 0,
  String? uid,
  String? nickname,
  String? fullName,
  String? email,
  String? phone,
  String? bio,
  int? birthYear = 1995,
  String? gender,
  List<String>? interests,
  List<String>? occupations,
  String? lookingFor,
  String? city,
  String? country,
  double? latitudeExact,
  double? longitudeExact,
  String? manualLocationText,
  String? avatarUrl,
  List<String>? photoUrls,
  String? avatarRacyLevel,
  List<String>? photoRacyLevels,
  bool allowVideoCall = false,
  bool allowDirectChat = false,
  bool isPublished = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.now();
  return UserProfileTableData(
    id: id,
    uid: uid,
    nickname: nickname,
    fullName: fullName,
    email: email,
    phone: phone,
    bio: bio,
    birthYear: birthYear,
    gender: gender,
    interests: interests,
    occupations: occupations,
    lookingFor: lookingFor,
    city: city,
    country: country,
    latitudeExact: latitudeExact,
    longitudeExact: longitudeExact,
    manualLocationText: manualLocationText,
    avatarUrl: avatarUrl,
    photoUrls: photoUrls,
    avatarRacyLevel: avatarRacyLevel,
    photoRacyLevels: photoRacyLevels,
    allowVideoCall: allowVideoCall,
    allowDirectChat: allowDirectChat,
    isPublished: isPublished,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

/// [SPoT] Fixture PrivacySettingsTableData για repository tests (drift).
/// Defaults = τα DB defaults (PrivcySettingsTable).
PrivacySettingsTableData privacySettingsData({
  int id = 0,
  String? uid,
  bool showNickname = true,
  bool showFullName = false,
  bool showAge = true,
  bool showGender = true,
  bool showCity = true,
  bool showExactLocation = false,
  bool showPhone = false,
  bool showEmail = false,
  bool showInterests = true,
  bool showOccupation = true,
  bool showBio = true,
  bool showLookingFor = true,
  bool showAvatar = true,
  bool showPhotos = true,
  bool showCountry = true,
  bool allowVideoCall = false,
  bool allowDirectChat = false,
  String geoPrecision = 'neighborhood',
}) =>
    PrivacySettingsTableData(
      id: id,
      uid: uid,
      showNickname: showNickname,
      showFullName: showFullName,
      showAge: showAge,
      showGender: showGender,
      showCity: showCity,
      showExactLocation: showExactLocation,
      showPhone: showPhone,
      showEmail: showEmail,
      showInterests: showInterests,
      showOccupation: showOccupation,
      showBio: showBio,
      showLookingFor: showLookingFor,
      showAvatar: showAvatar,
      showPhotos: showPhotos,
      showCountry: showCountry,
      allowVideoCall: allowVideoCall,
      allowDirectChat: allowDirectChat,
      geoPrecision: geoPrecision,
    );