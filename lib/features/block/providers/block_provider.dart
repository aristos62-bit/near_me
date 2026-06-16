import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../repositories/block_repository.dart';
import '../../../repositories/block_repository_impl.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'blockRepositoryProvider created');
  return BlockRepositoryImpl();
});

final blockedUidsProvider = StreamProvider.family<Set<String>, String>((ref, uid) {
  DebugConfig.log(DebugConfig.providerCreate, 'blockedUidsProvider created for $uid');
  final repo = ref.watch(blockRepositoryProvider);
  return repo.streamBlockedUids(uid);
});

class BlockActions {
  final BlockRepository _repo;

  BlockActions(this._repo);

  Future<void> block(String uid, String blockedUid, {String? reason}) =>
      _repo.blockUser(uid, blockedUid, reason: reason);

  Future<void> unblock(String uid, String blockedUid) =>
      _repo.unblockUser(uid, blockedUid);

  Future<bool> isBlocked(String uid, String blockedUid) =>
      _repo.isBlocked(uid, blockedUid);
}

final blockActionsProvider = Provider<BlockActions>((ref) {
  DebugConfig.log(DebugConfig.providerCreate, 'blockActionsProvider created');
  return BlockActions(ref.watch(blockRepositoryProvider));
});
