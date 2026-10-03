import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/repositories/chat_repository.dart';
import '../../helpers/chat_repository_test_base.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

/// Cache-hit/suppression tests για το anti-rebuild-storm machinery
/// (S174/S178/S200): global caches + equality suppression.
/// Κανόνας: `resetChatProviderCaches()` σε κάθε test (determinism).
Future<void> _waitFor(bool Function() cond) async {
  for (var i = 0; i < 40 && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(resetChatProviderCaches);

  group('chatDocProvider suppression (S174)', () {
    test('identical rewrite → suppressed (single emit)', () async {
      // Το fake ΔΕΝ εκπέμπει event σε πανομοιότυπο set, και το Riverpod κάνει
      // dedup ίδιων τιμών — γι' αυτό δύο διακριτά snaps με ίσα data μέσω
      // mock stream. Με σωστό suppression (S174) το 2ο event χαρτογραφείται
      // στο snap1 → ο provider δεν εκπέμπει ξανά (== ίδιο instance).
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      await h.seedChatDoc(chatId: 'cc-doc1');
      final snap1 = await h.firestore.collection('chats').doc('cc-doc1').get();
      final snap2 = await h.firestore.collection('chats').doc('cc-doc1').get();
      expect(identical(snap1, snap2), isFalse);

      final mockRepo = _MockChatRepository();
      when(() => mockRepo.chatDocStream(any()))
          .thenAnswer((_) => Stream.fromIterable([snap1, snap2]));
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(c.dispose);

      final emits = <DocumentSnapshot?>[];
      final sub = c.listen(
        chatDocProvider('cc-doc1'),
        (prev, next) => emits.add(next.asData?.value),
      );
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(emits.length, 1);
      expect(identical(emits[0], snap1), isTrue);
    });

    test('changed doc → new emit', () async {
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      await h.seedChatDoc(chatId: 'cc-doc2');
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(h.repo)],
      );
      addTearDown(c.dispose);

      final emits = <DocumentSnapshot?>[];
      final sub = c.listen(
        chatDocProvider('cc-doc2'),
        (prev, next) => emits.add(next.asData?.value),
      );
      addTearDown(sub.close);
      await _waitFor(() => emits.isNotEmpty);

      await h.firestore.collection('chats').doc('cc-doc2').update({
        'participantNicknames': {kTestUid: 'Me2', kTestOther: 'Other'},
      });
      await _waitFor(() => emits.length >= 2);

      expect(emits.length, 2);
      expect(identical(emits[0], emits[1]), isFalse);
      final data = emits[1]?.data() as Map<String, dynamic>?;
      expect(
        (data?['participantNicknames'] as Map)[kTestUid],
        'Me2',
      );
    });
  });

  group('participantUidsProvider cache (S178)', () {
    test('second read returns cached identical list', () async {
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      await h.seedChatDoc(
        chatId: 'cc-uids1',
        participants: const [kTestUid, kTestOther, 'u3'],
        extra: {
          'participantIsActive': {kTestUid: true, kTestOther: true, 'u3': false}
        },
      );
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(h.repo)],
      );
      addTearDown(c.dispose);
      final sub =
          c.listen(participantUidsProvider('cc-uids1'), (_, _) {});
      addTearDown(sub.close);
      await _waitFor(
          () => c.read(participantUidsProvider('cc-uids1')).isNotEmpty);

      final first = c.read(participantUidsProvider('cc-uids1'));
      final second = c.read(participantUidsProvider('cc-uids1'));
      expect(first, [kTestUid, kTestOther]);
      expect(identical(first, second), isTrue);
    });
  });

  group('message caches (S200)', () {
    test('stream populates encrypt caches → clear empties', () async {
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      await h.seedChatDoc(chatId: 'cc-cache1');
      final repo = h.repo;

      await repo.sendMessage('cc-cache1', 'γεια');
      final emits = <List<Map<String, dynamic>>>[];
      final sub = repo.messagesStream('cc-cache1').listen(emits.add);
      addTearDown(sub.cancel);
      await _waitFor(() => emits.isNotEmpty);

      expect(repo.messageEncryptCache['cc-cache1'], isNotEmpty);
      expect(repo.messageDecryptCache['cc-cache1'], isNotEmpty);

      repo.clearMessageCaches('cc-cache1');
      expect(repo.messageEncryptCache.containsKey('cc-cache1'), isFalse);
      expect(repo.messageDecryptCache.containsKey('cc-cache1'), isFalse);
    });

    test('messagesStream identical rewrite → identical list', () async {
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      await h.seedChatDoc(chatId: 'cc-msgs1');
      await h.seedMessage('cc-msgs1', 'm1', content: 'ένα');

      final emits = <List<Map<String, dynamic>>>[];
      final sub =
          h.repo.messagesStream('cc-msgs1').listen(emits.add);
      addTearDown(sub.cancel);
      await _waitFor(() => emits.isNotEmpty);

      await h.firestore
          .collection('chats')
          .doc('cc-msgs1')
          .collection('messages')
          .doc('m1')
          .set({
        'senderId': kTestOther,
        'content': 'ένα',
        'type': 'text',
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'isRead': false,
      });
      await _waitFor(() => emits.length >= 2);

      expect(emits.length, 2);
      expect(identical(emits[0], emits[1]), isTrue);
    });
  });

  group('streamChats suppression (S216)', () {
    test('unchanged rows → no duplicate emit', () async {
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      await h.seedCacheRow(chatId: 'cc-list1', otherNickname: 'Other');

      final emits = <Object>[];
      final sub = h.repo.streamChats().listen(emits.add);
      addTearDown(sub.cancel);
      await _waitFor(() => emits.isNotEmpty);
      expect(emits.length, 1);

      await h.repo.updateChatCache('cc-list1', hasUnread: false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(emits.length, 1);
    });
  });
}
