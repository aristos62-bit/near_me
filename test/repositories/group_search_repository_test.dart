import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/core/utils/app_exception.dart';
import 'package:near_me/repositories/group_search_repository.dart';

import '../helpers/failing_firestore.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreGroupSearchRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreGroupSearchRepository(firestore: firestore);
  });

  final ts = Timestamp.fromDate(DateTime.now());

  Future<void> seedGroup({
    required String chatId,
    String groupName = 'Ομάδα',
    String? city,
    List<String> tags = const [],
    bool isPublic = true,
  }) {
    return firestore.collection('groups').doc(chatId).set({
      'chatId': chatId,
      'groupName': groupName,
      'memberCount': 3,
      'tags': tags,
      'city': ?city,
      'isPublic': isPublic,
      'createdBy': 'creator',
      'createdAt': ts,
      'updatedAt': ts,
    });
  }

  group('searchGroups', () {
    test('κενό query → επιστρέφει μόνο τα public', () async {
      await seedGroup(chatId: 'g1', groupName: 'Αθήνα');
      await seedGroup(chatId: 'g2', groupName: 'Ιδιωτική', isPublic: false);

      final results = await repo.searchGroups();
      expect(results.map((g) => g.chatId), ['g1']);
      expect(results.single.groupName, 'Αθήνα');
    });

    test('φίλτρο city', () async {
      await seedGroup(chatId: 'g1', groupName: 'Αθήνα', city: 'Athens');
      await seedGroup(chatId: 'g2', groupName: 'Θεσσαλονίκη', city: 'Thessaloniki');

      final results = await repo.searchGroups(city: 'Athens');
      expect(results.map((g) => g.chatId), ['g1']);
    });

    test('φίλτρο tags (arrayContainsAny)', () async {
      await seedGroup(chatId: 'g1', groupName: 'Ομάδα', tags: ['sports']);
      await seedGroup(chatId: 'g2', groupName: 'Άλλη', tags: ['music']);

      final results = await repo.searchGroups(tags: ['sports']);
      expect(results.map((g) => g.chatId), ['g1']);
    });

    test('φίλτρο query → case-insensitive στο groupName', () async {
      await seedGroup(chatId: 'g1', groupName: 'Fotografia Club');
      await seedGroup(chatId: 'g2', groupName: 'Μουσική');

      final results = await repo.searchGroups(query: 'foto');
      expect(results.map((g) => g.chatId), ['g1']);
    });

    test('limit clamp: 0 → σαν 1, πάνω από 100 → σαν 100', () async {
      for (var i = 0; i < 5; i++) {
        await seedGroup(chatId: 'g$i', groupName: 'Ομάδα $i');
      }

      final zero = await repo.searchGroups(limit: 0);
      expect(zero.length, lessThanOrEqualTo(1));

      final huge = await repo.searchGroups(limit: 5000);
      expect(huge.length, lessThanOrEqualTo(100));
      expect(huge.length, 5);
    });
  });

  group('createPublicProfile', () {
    test('γράφει doc με όλα τα πεδία + optional + serverTimestamp', () async {
      final profile = GroupPublicProfile(
        chatId: 'g_new',
        groupName: 'Νέα',
        groupAvatarUrl: 'https://img/a.png',
        groupAvatarRacyLevel: 'VERY_UNLIKELY',
        memberCount: 5,
        description: 'περιγραφή',
        tags: const ['a', 'b'],
        city: 'Athens',
        createdBy: 'creator',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.createPublicProfile('g_new', profile);

      final doc = await firestore.collection('groups').doc('g_new').get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['chatId'], 'g_new');
      expect(data['groupName'], 'Νέα');
      expect(data['groupAvatarUrl'], 'https://img/a.png');
      expect(data['groupAvatarRacyLevel'], 'VERY_UNLIKELY');
      expect(data['memberCount'], 5);
      expect(data['description'], 'περιγραφή');
      expect(data['tags'], ['a', 'b']);
      expect(data['city'], 'Athens');
      expect(data['isPublic'], isTrue);
      expect(data['createdBy'], 'creator');
      expect(data['createdAt'], isNotNull);
      expect(data['updatedAt'], isNotNull);
    });

    test('Firestore λάθος → AppException firestore_error', () async {
      final failingRepo = FirestoreGroupSearchRepository(
        firestore: failingGroupWriteFirestore(chatId: 'g_new'),
      );
      final profile = GroupPublicProfile(
        chatId: 'g_new',
        groupName: 'Νέα',
        createdBy: 'creator',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await expectLater(
        failingRepo.createPublicProfile('g_new', profile),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'firestore_error')),
      );
    });
  });

  group('updatePublicProfile', () {
    test('παρουσία τιμών → update αυτές', () async {
      await seedGroup(chatId: 'g1', groupName: 'Παλιό');

      final profile = GroupPublicProfile(
        chatId: 'g1',
        groupName: 'Νέο',
        groupAvatarUrl: 'https://img/new.png',
        groupAvatarRacyLevel: 'VERY_UNLIKELY',
        memberCount: 8,
        description: 'νέα περιγραφή',
        tags: const ['z'],
        city: 'Athens',
        createdBy: 'creator',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.updatePublicProfile('g1', profile);

      final data = (await firestore.collection('groups').doc('g1').get()).data()!;
      expect(data['groupName'], 'Νέο');
      expect(data['groupAvatarUrl'], 'https://img/new.png');
      expect(data['memberCount'], 8);
      expect(data['description'], 'νέα περιγραφή');
      expect(data['tags'], ['z']);
      expect(data['city'], 'Athens');
    });

    test('απουσία τιμών → FieldValue.delete (κλειδιά σβήνονται)', () async {
      await seedGroup(chatId: 'g1', groupName: 'Ομάδα');

      final profile = GroupPublicProfile(
        chatId: 'g1',
        groupName: 'Μόνο name',
        memberCount: 1,
        createdBy: 'creator',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.updatePublicProfile('g1', profile);

      final data = (await firestore.collection('groups').doc('g1').get()).data()!;
      expect(data['groupName'], 'Μόνο name');
      expect(data.containsKey('groupAvatarUrl'), isFalse);
      expect(data.containsKey('description'), isFalse);
      expect(data.containsKey('tags'), isFalse);
      expect(data.containsKey('city'), isFalse);
    });
  });

  group('deletePublicProfile', () {
    test('διαγράφει το doc', () async {
      await seedGroup(chatId: 'g1', groupName: 'Ομάδα');
      await repo.deletePublicProfile('g1');

      final exists = (await firestore.collection('groups').doc('g1').get()).exists;
      expect(exists, isFalse);
    });
  });
}
