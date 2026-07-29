import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../shared/models/user_status.dart';
import '../../profile/providers/profile_provider.dart';

export '../../../shared/models/user_status.dart' show UserStatus;

final userStatusProvider = StreamProvider.autoDispose.family<UserStatus, String>((ref, uid) {
  DebugConfig.log(DebugConfig.providerCreate, 'userStatusProvider created for uid: $uid');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'userStatusProvider disposed for uid: $uid'));
  final profileRepo = ref.watch(profileRepositoryProvider);
  return profileRepo.streamUserStatus(uid);
});