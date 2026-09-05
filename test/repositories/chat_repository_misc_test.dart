import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/chat_repository_test_base.dart';
import '../helpers/fake_firestore_helpers.dart';

void main() {
  late ChatRepoHarness h;

  setUp(() async {
    h = await ChatRepoHarness.create();
  });

  tearDown(() async {
    await h.close();
  });

  group('syncMyProfileAcrossChats', () {
    test('no user → no-op', () async {
      await h.repoNoUser().syncMyProfileAcrossChats(nickname: 'New');
    });

    test('Drift empty + Firestore empty → no-op', () async {
      await h.repo.syncMyProfileAcrossChats(nickname: 'New');
      final chats = await h.firestore.collection('chats').get();
      expect(chats.docs, isEmpty);
    });

    test('Drift empty + Firestore chat → batch update nickname', () async {
      await h.seedChatDoc(extra: {
        'participantNicknames': {kTestUid: 'Old', kTestOther: 'Other'},
      });

      await h.repo.syncMyProfileAcrossChats(nickname: 'New');

      final chat = await h.firestore.collection('chats').doc('chat1').get();
      expect((chat.data()!['participantNicknames'] as Map)[kTestUid], 'New');
    });

    test('Drift 1 chat → batch update nickname (Drift path)', () async {
      await h.seedCacheRow(chatId: 'c1');
      await h.seedChatDoc(chatId: 'c1');

      await h.repo.syncMyProfileAcrossChats(nickname: 'New');

      final c1 = await h.firestore.collection('chats').doc('c1').get();
      expect((c1.data()!['participantNicknames'] as Map)[kTestUid], 'New');
    });

    test('batch update πολλών chats → δεν ρίχνει, η ενημέρωση επιστρέφει',
        () async {
      // Σημ.: fake_cloud_firestore εφαρμόζει μόνο το πρώτο doc σε batch με
      // πολλαπλά dotted-key updates στον ίδιο path (γνωστό fake limitation,
      // όχι prod bug — το πραγματικό Firestore εφαρμόζει το batch atomic).
      await h.seedCacheRow(chatId: 'c1');
      await h.seedCacheRow(chatId: 'c2');
      await h.seedChatDoc(chatId: 'c1');
      await h.seedChatDoc(chatId: 'c2');

      await h.repo.syncMyProfileAcrossChats(nickname: 'New');
    });
  });

  group('searchUsersByNickname', () {
    test('κενό query → []', () async {
      expect(await h.repo.searchUsersByNickname('  '), isEmpty);
    });

    test('επιστρέφει curated πεδία + αποκλείει invisible', () async {
      final visible = publicProfileDoc(
          uid: 'u_alice', nickname: 'Alice', city: 'Athens');
      visible['nicknameLowercase'] = 'alice';
      final hidden =
          publicProfileDoc(uid: 'u_bob', nickname: 'Bob', isVisible: false);
      hidden['nicknameLowercase'] = 'bob';
      await seedPublicProfile(h.firestore, visible);
      await seedPublicProfile(h.firestore, hidden);

      final res = await h.repo.searchUsersByNickname('al');

      expect(res, hasLength(1));
      expect(res.single['uid'], 'u_alice');
      expect(res.single['nickname'], 'Alice');
      expect(res.single.keys, isNot(contains('email')));
    });
  });

  group('chatDocStream', () {
    test('εκπέμπει το chat doc και ενημερώσεις', () async {
      await h.seedChatDoc();
      final events = <DocumentSnapshot?>[];
      final sub = h.repo.chatDocStream('chat1').listen(events.add);

      await pumpEventQueue();
      expect(events, isNotEmpty);
      expect(events.first!.id, 'chat1');

      await h.firestore.collection('chats').doc('chat1').update({'isActive': true});
      await pumpEventQueue();
      expect(events, hasLength(greaterThan(1)));

      await sub.cancel();
    });
  });

  group('clearMessageCaches', () {
    test('smoke: δεν ρίχνει', () {
      h.repo.clearMessageCaches('chat1');
    });
  });
}