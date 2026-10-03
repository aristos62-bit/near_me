import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/repositories/chat_repository.dart';
import '../../helpers/chat_repository_test_base.dart';
import '../../helpers/connectivity_mocks.dart';

/// Unit tests για OlderMessages/combined/participantUids + reply/edit/
/// pending notifiers (καθαρή λογική, χωρίς streams Firebase).
/// Κανόνας: μοναδικά chatIds ανά test (module-level caches).
class _MockChatRepository extends Mock implements ChatRepository {}

ProviderContainer _container(_MockChatRepository repo) => ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );

Map<String, dynamic> _msg(String id, String text) => {
      'id': id,
      'senderId': 'u1',
      'content': text,
      'type': 'text',
      'timestamp': null,
      'isRead': true,
    };

void main() {
  group('OlderMessagesByChat.loadMore', () {
    test('offline → χωρίς repo call', () async {
      await mockConnectivityOffline();
      addTearDown(resetConnectivityMock);
      final repo = _MockChatRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      await c
          .read(olderMessagesByChatProvider.notifier)
          .loadMore('chat-off1', DateTime(2026, 1, 1));
      verifyNever(() => repo.fetchOlderMessages(any(),
          beforeTimestamp: any(named: 'beforeTimestamp'),
          limit: any(named: 'limit')));
      expect(
          c
              .read(olderMessagesByChatProvider.notifier)
              .stateFor('chat-off1')
              .messages,
          isEmpty);
    });

    test('success → prepend + hasMore=false (<50)', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockChatRepository();
      when(() => repo.fetchOlderMessages(any(),
              beforeTimestamp: any(named: 'beforeTimestamp'),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [_msg('old1', 'παλιό')]);
      final c = _container(repo);
      addTearDown(c.dispose);
      await c
          .read(olderMessagesByChatProvider.notifier)
          .loadMore('chat-old1', DateTime(2026, 6, 1));
      final s = c
          .read(olderMessagesByChatProvider.notifier)
          .stateFor('chat-old1');
      expect(s.messages.map((m) => m['id']), ['old1']);
      expect(s.hasMore, isFalse);
      expect(s.isLoading, isFalse);
    });

    test('fail → isLoading false, χωρίς crash', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockChatRepository();
      when(() => repo.fetchOlderMessages(any(),
              beforeTimestamp: any(named: 'beforeTimestamp'),
              limit: any(named: 'limit')))
          .thenThrow(Exception('boom'));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c
          .read(olderMessagesByChatProvider.notifier)
          .loadMore('chat-old2', DateTime(2026, 6, 1));
      expect(
          c
              .read(olderMessagesByChatProvider.notifier)
              .stateFor('chat-old2')
              .isLoading,
          isFalse);
    });
  });

  group('combinedMessagesProvider', () {
    test('merge older+live με dedup και σειρά', () async {
      await mockConnectivityOnline();
      addTearDown(resetConnectivityMock);
      final repo = _MockChatRepository();
      when(() => repo.fetchOlderMessages(any(),
              beforeTimestamp: any(named: 'beforeTimestamp'),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [_msg('m1', 'ένα'), _msg('m0', 'μηδέν')]);
      when(() => repo.messagesStream(any()))
          .thenAnswer((_) => Stream.value([_msg('m1', 'ένα'), _msg('m2', 'δύο')]));
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      await c
          .read(olderMessagesByChatProvider.notifier)
          .loadMore('chat-comb1', DateTime(2026, 6, 1));
      final sub = c.listen(combinedMessagesProvider('chat-comb1'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final merged = c.read(combinedMessagesProvider('chat-comb1'));
      sub.close();
      expect(merged.map((m) => m['id']), ['m0', 'm1', 'm2']);
    });
  });

  group('participantUidsProvider (μέσω real repo + fake Firestore)', () {
    test('φιλτράρει ανενεργούς', () async {
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      await h.seedChatDoc(
        chatId: 'chat-part1',
        participants: const ['u_test', 'u2', 'u3'],
        extra: {
          'participantIsActive': {'u_test': true, 'u2': true, 'u3': false}
        },
      );
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(h.repo)],
      );
      addTearDown(c.dispose);
      final sub =
          c.listen(participantUidsProvider('chat-part1'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final uids = c.read(participantUidsProvider('chat-part1'));
      sub.close();
      expect(uids, ['u_test', 'u2']);
    });

    test('missing doc → []', () async {
      final h = await ChatRepoHarness.create();
      addTearDown(h.close);
      final c = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(h.repo)],
      );
      addTearDown(c.dispose);
      final sub =
          c.listen(participantUidsProvider('chat-part2'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final uids = c.read(participantUidsProvider('chat-part2'));
      sub.close();
      expect(uids, isEmpty);
    });
  });

  group('ReplyTo/Editing/PendingPrivateReply notifiers', () {
    test('reply set/clear + clear-missing no-op', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(replyToMessageProvider.notifier);
      n.setReply('c1', {'id': 'm1'});
      expect(c.read(replyToMessageProvider)['c1']?['id'], 'm1');
      n.clear('c1');
      expect(c.read(replyToMessageProvider).containsKey('c1'), isFalse);
      n.clear('missing');
      expect(c.read(replyToMessageProvider), isEmpty);
    });

    test('edit set/clear', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(editingMessageProvider.notifier);
      n.setEdit('c1', {'id': 'm9'});
      expect(c.read(editingMessageProvider)['c1']?['id'], 'm9');
      n.clear('c1');
      expect(c.read(editingMessageProvider), isEmpty);
    });

    test('pending consume match/mismatch/empty', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(pendingPrivateReplyProvider.notifier);
      expect(n.consumeFor('c1'), isNull);
      n.set('c1', {'id': 'm5'});
      expect(n.consumeFor('other'), isNull);
      final got = n.consumeFor('c1');
      expect(got?.quotedMessage['id'], 'm5');
      expect(n.consumeFor('c1'), isNull);
    });
  });
}
