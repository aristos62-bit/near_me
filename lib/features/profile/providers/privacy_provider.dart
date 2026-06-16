import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../data/local/database.dart';
import 'profile_provider.dart';

final privacySettingsProvider = FutureProvider<PrivacySettingsTableData?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final settings = await repo.getPrivacySettings();
  DebugConfig.log(DebugConfig.providerCreate, 'privacySettingsProvider loaded: ${settings != null}');
  return settings;
});
