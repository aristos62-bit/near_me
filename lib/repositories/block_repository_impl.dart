import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import '../data/local/database.dart';
import '../data/local/database_service.dart';
import 'block_repository.dart';
import '../core/debug/debug_config.dart';
import '../core/utils/app_exception.dart';

class BlockRepositoryImpl implements BlockRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  BlockRepositoryImpl({AppDatabase? db, FirebaseFirestore? firestore})
      : _db = db ?? DatabaseService.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> blockUser(String uid, String blockedUid, {String? reason}) async {
    DebugConfig.log(DebugConfig.firestoreWrite, 'BlockRepository blockUser: $blockedUid');
    if (uid.isEmpty || blockedUid.isEmpty) {
      throw const AppException(
        message: 'Invalid uids for block operation',
        code: 'validation_error',
      );
    }

    final existing = await (_db.select(_db.blockedUserTable)
      ..where((t) => t.uid.equals(uid) & t.blockedUid.equals(blockedUid))
      ..limit(1)
    ).get();
    if (existing.isNotEmpty) return;

    await _db.into(_db.blockedUserTable).insert(BlockedUserTableCompanion.insert(
      uid: Value(uid),
      blockedUid: Value(blockedUid),
      blockedAt: Value(DateTime.now()),
      reason: Value(reason),
    ));

    try {
      await _firestore
          .collection('users').doc(uid).collection('blocked').doc(blockedUid)
          .set({'blockedAt': FieldValue.serverTimestamp(), 'reason': reason ?? ''});
    } catch (e) {
      DebugConfig.warn('BlockRepository: Firestore sync failed (non-fatal): $e');
    }
  }

  @override
  Future<void> unblockUser(String uid, String blockedUid) async {
    DebugConfig.log(DebugConfig.firestoreWrite, 'BlockRepository unblockUser: $blockedUid');
    if (uid.isEmpty || blockedUid.isEmpty) return;

    await (_db.delete(_db.blockedUserTable)..where((t) => t.uid.equals(uid) & t.blockedUid.equals(blockedUid))).go();

    try {
      await _firestore
          .collection('users').doc(uid).collection('blocked').doc(blockedUid)
          .delete();
    } catch (e) {
      DebugConfig.warn('BlockRepository: Firestore sync failed (non-fatal): $e');
    }
  }

  @override
  Future<bool> isBlocked(String uid, String blockedUid) async {
    DebugConfig.log(DebugConfig.databaseLocal, 'BlockRepository isBlocked: $blockedUid');
    if (uid.isEmpty || blockedUid.isEmpty) return false;

    final existing = await (_db.select(_db.blockedUserTable)
      ..where((t) => t.uid.equals(uid) & t.blockedUid.equals(blockedUid))
      ..limit(1)
    ).get();
    return existing.isNotEmpty;
  }

  @override
  Future<List<BlockedUserTableData>> getBlockedUsers(String uid) async {
    DebugConfig.log(DebugConfig.databaseLocal, 'BlockRepository getBlockedUsers: $uid');
    if (uid.isEmpty) return [];

    try {
      final rows = await (_db.select(_db.blockedUserTable)
        ..where((t) => t.uid.equals(uid))
        ..orderBy([(t) => OrderingTerm.desc(t.blockedAt)])
      ).get();
      DebugConfig.log(DebugConfig.repositoryResult, 'getBlockedUsers: ${rows.length} entries');
      return rows;
    } catch (e, s) {
      DebugConfig.error('getBlockedUsers failed', data: e, exception: s);
      throw AppException.database('getBlockedUsers', e, s);
    }
  }

  @override
  Stream<Set<String>> streamBlockedUids(String uid) {
    DebugConfig.log(DebugConfig.databaseLocalStream, 'BlockRepository streamBlockedUids: $uid');
    if (uid.isEmpty) {
      DebugConfig.warn('streamBlockedUids: empty uid');
      return Stream.value(<String>{});
    }

    try {
      return (_db.select(_db.blockedUserTable)
        ..where((t) => t.uid.equals(uid))
      ).watch().map((rows) => rows.map((r) => r.blockedUid).toSet());
    } catch (e, s) {
      DebugConfig.error('streamBlockedUids failed', data: e, exception: s);
      rethrow;
    }
  }
}