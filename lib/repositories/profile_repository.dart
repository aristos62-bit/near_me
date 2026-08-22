import 'dart:typed_data';
import '../data/local/database.dart';
import '../shared/models/public_profile.dart';
import '../shared/models/user_status.dart';

abstract class ProfileRepository {
  Future<UserProfileTableData?> getProfile();
  Future<void> saveProfile(UserProfileTableData profile);
  Future<void> deleteProfile();
  Future<PrivacySettingsTableData?> getPrivacySettings();
  Future<void> savePrivacySettings(PrivacySettingsTableData settings);
  Future<void> publish();
  Future<void> unpublish();
  Future<bool> get isPublished;

  /// Ενεργοποιεί/απενεργοποιεί το SOS (helpRequest) στο public doc.
  /// Ενεργό: update nested `helpRequest` (message ≤ 80 chars, radiusKm,
  /// updatedAt σε UTC ISO8601). Απενεργοποίηση: `FieldValue.delete()`.
  Future<void> setHelpRequest({
    required bool active,
    String? message,
    double? radiusKm,
  });

  /// Αποθηκεύει νέες συντεταγμένες + πόλη/χώρα στο Drift.
  /// Πάντα αποθηκεύει lat/lng. Αποθηκεύει city/country μόνο αν δοθούν.
  /// Επιστρέφει το αποθηκευμένο profile για αποφυγή redundant getProfile().
  /// ΔΕΝ κάνει publish — ο caller αποφασίζει το πότε με βάση policy.
  Future<UserProfileTableData?> syncLocation(double lat, double lng, {String? city, String? country});
  Stream<PublicProfile?> publicProfileStream();
  Future<PublicProfile?> getPublicProfile(String uid);
  Stream<PublicProfile?> streamPublicProfile(String uid);
  Stream<UserStatus> streamUserStatus(String uid);
  Stream<UserProfileTableData?> streamProfile();

  Future<String> saveAvatar(Uint8List bytes);
  Future<void> deleteAvatar();
  Future<String> savePhoto(Uint8List bytes, int index);
  Future<void> deletePhoto(int index);
}
