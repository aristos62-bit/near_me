import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_status.dart';
import '../../profile/providers/profile_provider.dart';

export '../../../shared/models/user_status.dart' show UserStatus;

final userStatusProvider = StreamProvider.autoDispose.family<UserStatus, String>((ref, uid) {
  final profileRepo = ref.watch(profileRepositoryProvider);
  return profileRepo.streamUserStatus(uid);
});