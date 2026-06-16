import 'dart:async';
import '../data/local/database.dart';

abstract class BlockRepository {
  Future<void> blockUser(String uid, String blockedUid, {String? reason});

  Future<void> unblockUser(String uid, String blockedUid);

  Future<bool> isBlocked(String uid, String blockedUid);

  Future<List<BlockedUserTableData>> getBlockedUsers(String uid);

  Stream<Set<String>> streamBlockedUids(String uid);
}
