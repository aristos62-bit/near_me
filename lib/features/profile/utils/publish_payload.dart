import 'dart:ui' show PlatformDispatcher;

import '../../../data/local/database.dart';
import '../../../shared/models/public_profile.dart';

/// [SPoT] Build του public payload για το `publish()` — move-only από το
/// `profile_repository_impl.dart`, χωρίς καμία αλλαγή λογικής.
PublicProfile buildPublicProfileForPublish({
  required String uid,
  required UserProfileTableData profile,
  required PrivacySettingsTableData? privacy,
  required DateTime now,
}) {
  return PublicProfile(
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
    avatarRacyLevel: privacy?.showAvatar == true ? profile.avatarRacyLevel : null,
    photoRacyLevels: privacy?.showPhotos == true ? profile.photoRacyLevels : null,
    email: privacy?.showEmail == true ? profile.email : null,
    phone: privacy?.showPhone == true ? profile.phone : null,
    allowVideoCall: privacy?.allowVideoCall ?? false,
    allowDirectChat: privacy?.allowDirectChat ?? false,
    isManualLocation: profile.latitudeExact == null && profile.longitudeExact == null,
    isVisible: true,
    lang: PlatformDispatcher.instance.locale.languageCode == 'el' ? 'el' : 'en',
    updatedAt: now,
  );
}

/// [SPoT] JSON του public payload: `toJson()` καθαρό από nulls, χωρίς `isOnline`
/// (server-side presence field), + normalized fields για case-insensitive search.
/// Move-only από το `publish()`.
Map<String, dynamic> publicProfileToPayloadJson(PublicProfile publicProfile) {
  final json = publicProfile.toJson()
    ..removeWhere((_, v) => v == null)
    ..remove('isOnline');

  if (publicProfile.city != null && publicProfile.city!.isNotEmpty) {
    json['cityNormalized'] = publicProfile.city!.toLowerCase().trim();
  }
  if (publicProfile.country != null && publicProfile.country!.isNotEmpty) {
    json['countryNormalized'] = publicProfile.country!.toLowerCase().trim();
  }
  if (publicProfile.nickname != null && publicProfile.nickname!.isNotEmpty) {
    json['nicknameLowercase'] = publicProfile.nickname!.toLowerCase().trim();
  }
  return json;
}

/// [SPoT] Preserve του υπάρχοντος `isOnline`/`geoHash`/`helpRequest` στο payload.
///
/// Move-only από το `publish()`. ΠΡΟΣΟΧΗ: η συνάρτηση τροποποιεί (mutates) το
/// [json] επί τόπου — οι casts μπορούν να πετάξουν TypeError και ο caller
/// ΠΡΕΠΕΙ να την καλεί μέσα στο δικό του try/catch (όπως σήμερα), αλλιώς
/// αλλάζει η διάδοση σφαλμάτων.
void applyPublishPreserves(
  Map<String, dynamic> json, {
  required Map<String, dynamic>? existing,
  required bool canCommunicate,
}) {
  if (existing == null) return;
  final existingIsOnline = existing['isOnline'];
  if (existingIsOnline != null) {
    json['isOnline'] = existingIsOnline as bool;
  }
  final existingGeoHash = existing['geoHash'];
  if (existingGeoHash != null) {
    json['geoHash'] = existingGeoHash as String;
  }
  final existingHelpRequest = existing['helpRequest'];
  if (existingHelpRequest != null && canCommunicate) {
    json['helpRequest'] = existingHelpRequest;
  }
}