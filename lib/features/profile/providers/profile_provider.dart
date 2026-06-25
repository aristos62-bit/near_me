import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../data/local/database.dart';
import '../../../providers/database_provider.dart';
import '../../../repositories/profile_repository.dart';
import '../../../repositories/profile_repository_impl.dart';
import '../../../shared/models/public_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(databaseProvider);
  DebugConfig.log(DebugConfig.providerCreate, 'profileRepositoryProvider created');
  return ProfileRepositoryImpl(
    db: db,
    firestore: FirebaseFirestore.instance,
  );
});

final currentProfileProvider = StreamProvider.autoDispose<UserProfileTableData?>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'currentProfileProvider stream created');
  final repo = ref.watch(profileRepositoryProvider);
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'currentProfileProvider disposed'));
  return repo.streamProfile();
});

final publicProfileStreamProvider = StreamProvider.autoDispose.family<PublicProfile?, String>((ref, uid) {
  DebugConfig.log(DebugConfig.providerCreate, 'publicProfileStreamProvider created for uid: $uid');
  final repo = ref.watch(profileRepositoryProvider);
  return repo.streamPublicProfile(uid);
});
