import 'package:drift/drift.dart';
import '../../../core/debug/debug_config.dart';
import '../../../repositories/profile_repository.dart';

/// Καθαρίζει το τοπικό τηλέφωνο μετά από επιτυχές unlink (+ re-publish
/// του δημόσιου snapshot αν ήταν δημοσιευμένο).
///
/// SPoT — ο μόνος λόγος ύπαρξης ξεχωριστού αρχείου είναι το όριο
/// 500 γραμμών (settings_screen 499, profile_repository_impl 744/765).
/// Καλείται warn-only: ποτέ δεν ανατρέπει το unlink-success.
Future<void> clearLocalPhone(ProfileRepository repo) async {
  DebugConfig.log(DebugConfig.repositoryCall, 'clearLocalPhone');
  final profile = await repo.getProfile();
  final phone = profile?.phone;
  if (profile == null || phone == null || phone.isEmpty) return;
  await repo.saveProfile(profile.copyWith(phone: const Value(null)));
  DebugConfig.log(
      DebugConfig.databaseLocal, 'clearLocalPhone: local phone cleared');
  if (profile.isPublished) {
    await repo.publish();
    DebugConfig.log(DebugConfig.firestoreWrite,
        'clearLocalPhone: public snapshot refreshed');
  }
}
