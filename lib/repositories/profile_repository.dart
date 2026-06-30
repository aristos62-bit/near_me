import 'dart:typed_data';
import '../data/local/database.dart';
import '../shared/models/public_profile.dart';

abstract class ProfileRepository {
  Future<UserProfileTableData?> getProfile();
  Future<void> saveProfile(UserProfileTableData profile);
  Future<void> deleteProfile();
  Future<PrivacySettingsTableData?> getPrivacySettings();
  Future<void> savePrivacySettings(PrivacySettingsTableData settings);
  Future<void> publish();
  Future<void> unpublish();
  Future<bool> get isPublished;

  /// Αποθηκεύει νέες συντεταγμένες + πόλη/χώρα στο Drift.
  /// Πάντα αποθηκεύει lat/lng. Αποθηκεύει city/country μόνο αν δοθούν.
  /// ΔΕΝ κάνει publish — ο caller αποφασίζει το πότε με βάση policy.
  Future<void> syncLocation(double lat, double lng, {String? city, String? country});
  Stream<PublicProfile?> publicProfileStream();
  Future<PublicProfile?> getPublicProfile(String uid);
  Stream<PublicProfile?> streamPublicProfile(String uid);
  Stream<UserProfileTableData?> streamProfile();

  Future<String> saveAvatar(Uint8List bytes);
  Future<void> deleteAvatar();
  Future<String> savePhoto(Uint8List bytes, int index);
  Future<void> deletePhoto(int index);
}
