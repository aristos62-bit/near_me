import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/repositories/block_repository_impl.dart';

import '../helpers/failing_firestore.dart';

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late BlockRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    repo = BlockRepositoryImpl(db: db, firestore: firestore);
  });

  tearDown(() async {
    await db.close();
  });

  group('blockUser', () {
    test('κενό uid → validation_error', () async {
      await expectLater(
        repo.blockUser('', 'blocked'),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('κενό blockedUid → validation_error', () async {
      await expectLater(
        repo.blockUser('me', ''),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('επιτυχία → γράφει Drift row + Firestore doc', () async {
      await repo.blockUser('me', 'them', reason: 'spam');

      final rows = await (db.select(db.blockedUserTable)).get();
      expect(rows, hasLength(1));
      expect(rows.first.uid, 'me');
      expect(rows.first.blockedUid, 'them');
      expect(rows.first.reason, 'spam');
      expect(rows.first.blockedAt, isNotNull);

      final doc = await firestore
          .collection('users').doc('me').collection('blocked').doc('them')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['reason'], 'spam');
    });

    test('διπλό block → idempotent (ένα μόνο Drift row)', () async {
      await repo.blockUser('me', 'them');
      await repo.blockUser('me', 'them');
      final rows = await (db.select(db.blockedUserTable)).get();
      expect(rows, hasLength(1));
    });

    test('Firestore sync fail → non-fatal (Drift row παραμένει)', () async {
      final failingRepo = BlockRepositoryImpl(
        db: db,
        firestore: failingBlockWriteFirestore(),
      );
      await failingRepo.blockUser('me', 'them');

      final rows = await (db.select(db.blockedUserTable)).get();
      expect(rows, hasLength(1));
      expect(rows.first.blockedUid, 'them');
    });
  });

  group('unblockUser', () {
    test('κενά uid → no-op χωρίς throw', () async {
      await repo.unblockUser('', '');
      await repo.unblockUser('me', '');
      await repo.unblockUser('', 'them');
      final rows = await (db.select(db.blockedUserTable)).get();
      expect(rows, isEmpty);
    });

    test('επιτυχία → διαγραφή Drift + Firestore', () async {
      await repo.blockUser('me', 'them');
      await repo.unblockUser('me', 'them');

      final rows = await (db.select(db.blockedUserTable)).get();
      expect(rows, isEmpty);
      final doc = await firestore
          .collection('users').doc('me').collection('blocked').doc('them')
          .get();
      expect(doc.exists, isFalse);
    });

    test('Firestore delete fail → non-fatal (Drift διαγράφηκε)', () async {
      final failingRepo = BlockRepositoryImpl(
        db: db,
        firestore: failingBlockWriteFirestore(),
      );
      await failingRepo.blockUser('me', 'them');

      await failingRepo.unblockUser('me', 'them');

      final rows = await (db.select(db.blockedUserTable)).get();
      expect(rows, isEmpty);
    });
  });

  group('isBlocked', () {
    test('κενά uid → false', () async {
      expect(await repo.isBlocked('', 'x'), isFalse);
      expect(await repo.isBlocked('x', ''), isFalse);
    });

    test('blocked → true, αλλιώς false', () async {
      await repo.blockUser('me', 'them');
      expect(await repo.isBlocked('me', 'them'), isTrue);
      expect(await repo.isBlocked('me', 'other'), isFalse);
      expect(await repo.isBlocked('other', 'them'), isFalse);
    });
  });

  group('getBlockedUsers', () {
    test('κενό uid → []', () async {
      expect(await repo.getBlockedUsers(''), isEmpty);
    });

    test('επιτυχία → ταξινομημένα blockedAt DESC', () async {
      await db.into(db.blockedUserTable).insert(
        BlockedUserTableCompanion.insert(
          uid: const Value('me'),
          blockedUid: const Value('a'),
          blockedAt: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.into(db.blockedUserTable).insert(
        BlockedUserTableCompanion.insert(
          uid: const Value('me'),
          blockedUid: const Value('b'),
          blockedAt: Value(DateTime(2026, 2, 1)),
        ),
      );

      final rows = await repo.getBlockedUsers('me');
      expect(rows.map((r) => r.blockedUid).toList(), ['b', 'a']);
    });
  });

  group('streamBlockedUids', () {
    test('κενό uid → emits empty set', () async {
      final stream = repo.streamBlockedUids('');
      expect(await stream.toList(), [<String>{}]);
    });

    test('κανονικό → emit set με blocked uids', () async {
      await repo.blockUser('me', 'a');
      await repo.blockUser('me', 'b');

      final snapshots = await repo.streamBlockedUids('me').take(1).toList();
      expect(snapshots, isNotEmpty);
      expect(snapshots.first, {'a', 'b'});
    });
  });
}
