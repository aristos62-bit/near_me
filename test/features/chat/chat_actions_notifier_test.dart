import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/repositories/chat_repository.dart';
import '../../helpers/connectivity_mocks.dart';

/// Unit tests για `ChatActionsNotifier` (πλήρης ανάγνωση chat_provider).
/// Mock ChatRepository + connectivity mock. Το CF rate-limit σε VM πέφτει
/// στο fail-open catch (no-app) → ντετερμινιστικά true.
/// Το `resource-exhausted→false` branch μένει εκτός (θέλει CF mock).
class _MockChatRepository extends Mock implements ChatRepository {}

ProviderContainer _container(_MockChatRepository repo) => ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );

Future<void> _online() async {
  await mockConnectivityOnline();
  addTearDown(resetConnectivityMock);
}

Future<void> _offline() async {
  await mockConnectivityOffline();
  addTearDown(resetConnectivityMock);
}

void main() {
  group('ChatActionsNotifier gates', () {
    test('offline createChat → null + network code, χωρίς repo call',
        () async {
      await _offline();
      final repo = _MockChatRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      final r =
          await c.read(chatActionsProvider.notifier).createChat('other');
      expect(r, isNull);
      final s = c.read(chatActionsProvider);
      expect(s.status, ChatActionStatus.error);
      expect(s.errorMessage, 'network/no-connectivity');
      verifyNever(() => repo.createChat(any()));
    });

    test('offline sendMessage → false', () async {
      await _offline();
      final repo = _MockChatRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      expect(
          await c.read(chatActionsProvider.notifier).sendMessage('c', 'hi'),
          isFalse);
      verifyNever(() => repo.sendMessage(any(), any()));
    });

    test('reset → idle', () {
      final repo = _MockChatRepository();
      final c = _container(repo);
      addTearDown(c.dispose);
      c.read(chatActionsProvider.notifier).reset();
      expect(c.read(chatActionsProvider).status, ChatActionStatus.idle);
    });
  });

  group('ChatActionsNotifier 1-1', () {
    test('createChat success → id + invalidate', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.createChat(any())).thenAnswer((_) async => 'chat-1');
      final c = _container(repo);
      addTearDown(c.dispose);
      final r =
          await c.read(chatActionsProvider.notifier).createChat('other');
      expect(r, 'chat-1');
      final s = c.read(chatActionsProvider);
      expect(s.status, ChatActionStatus.success);
      expect(s.createdChatId, 'chat-1');
    });

    test('createChat fail → error με friendly code', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.createChat(any())).thenThrow(Exception('boom'));
      final c = _container(repo);
      addTearDown(c.dispose);
      final r =
          await c.read(chatActionsProvider.notifier).createChat('other');
      expect(r, isNull);
      final s = c.read(chatActionsProvider);
      expect(s.status, ChatActionStatus.error);
      expect(s.errorMessage, 'chat/unknown-error');
    });

    test('sendMessage success → true', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.sendMessage(any(), any())).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      expect(
          await c.read(chatActionsProvider.notifier).sendMessage('c', 'hi'),
          isTrue);
      expect(
          c.read(chatActionsProvider).status, ChatActionStatus.success);
    });

    test('sendMessage fail → false + error', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.sendMessage(any(), any()))
          .thenThrow(Exception('boom'));
      final c = _container(repo);
      addTearDown(c.dispose);
      expect(
          await c.read(chatActionsProvider.notifier).sendMessage('c', 'hi'),
          isFalse);
      expect(c.read(chatActionsProvider).status, ChatActionStatus.error);
    });

    test('markAsRead → repo call, ποτέ throw', () async {
      final repo = _MockChatRepository();
      when(() => repo.markAsRead(any(), isGroupChat: any(named: 'isGroupChat')))
          .thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(chatActionsProvider.notifier).markAsRead('c');
      verify(() => repo.markAsRead('c', isGroupChat: false)).called(1);
    });

    test('markAsRead fail → swallowed (warn-only)', () async {
      final repo = _MockChatRepository();
      when(() => repo.markAsRead(any(), isGroupChat: any(named: 'isGroupChat')))
          .thenThrow(Exception('boom'));
      final c = _container(repo);
      addTearDown(c.dispose);
      await c.read(chatActionsProvider.notifier).markAsRead('c');
      expect(c.read(chatActionsProvider).status, ChatActionStatus.idle);
    });
  });

  group('ChatActionsNotifier delete/react/edit', () {
    test('deleteChat + approve + reject + cancel → success', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.deleteChat(any())).thenAnswer((_) async {});
      when(() => repo.approveDeleteChat(any())).thenAnswer((_) async {});
      when(() => repo.rejectDeleteChat(any())).thenAnswer((_) async {});
      when(() => repo.cancelDeleteRequest(any())).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(chatActionsProvider.notifier);
      await n.deleteChat('c');
      expect(c.read(chatActionsProvider).status, ChatActionStatus.success);
      await n.approveDeleteChat('c');
      expect(c.read(chatActionsProvider).status, ChatActionStatus.success);
      await n.rejectDeleteChat('c');
      expect(c.read(chatActionsProvider).status, ChatActionStatus.success);
      await n.cancelDeleteRequest('c');
      expect(c.read(chatActionsProvider).status, ChatActionStatus.success);
    });

    test('react + unreact → success', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.addReaction(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => repo.removeReaction(any(), any())).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(chatActionsProvider.notifier);
      await n.reactToMessage('c', 'm', '👍');
      expect(c.read(chatActionsProvider).status, ChatActionStatus.success);
      await n.removeReaction('c', 'm');
      expect(c.read(chatActionsProvider).status, ChatActionStatus.success);
    });

    test('edit + delete message → true', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.editMessage(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => repo.deleteMessage(any(), any())).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(chatActionsProvider.notifier);
      expect(await n.editMessage('c', 'm', 'νέο'), isTrue);
      expect(await n.deleteMessage('c', 'm'), isTrue);
    });
  });

  group('ChatActionsNotifier groups/invites', () {
    test('createGroupChat + add/remove participant', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.createGroupChat(any(),
              groupName: any(named: 'groupName'),
              isPublic: any(named: 'isPublic'),
              description: any(named: 'description'),
              tags: any(named: 'tags'),
              city: any(named: 'city')))
          .thenAnswer((_) async => 'g1');
      when(() => repo.addParticipant(any(), any())).thenAnswer((_) async {});
      when(() => repo.removeParticipant(any(), any()))
          .thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(chatActionsProvider.notifier);
      expect(await n.createGroupChat(['u2'], groupName: 'Parea'), 'g1');
      expect(await n.addParticipant('g1', 'u3'), isTrue);
      expect(await n.removeParticipant('g1', 'u3'), isTrue);
    });

    test('createInviteLink + revoke + joinPublic', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.createInviteLink('g1',
              expiresIn: const Duration(days: 7), maxUses: null))
          .thenAnswer((_) async => 'tok');
      when(() => repo.revokeInvite(any(), any())).thenAnswer((_) async {});
      when(() => repo.joinPublicGroup(any())).thenAnswer((_) async {});
      final c = _container(repo);
      addTearDown(c.dispose);
      final n = c.read(chatActionsProvider.notifier);
      expect(await n.createInviteLink('g1'), 'tok');
      expect(await n.revokeInvite('g1', 'i1'), isTrue);
      expect(await n.joinPublicGroup('g1'), isTrue);
    });

    test('updateMaxParticipants fail → false + error', () async {
      await _online();
      final repo = _MockChatRepository();
      when(() => repo.updateMaxParticipants('g1', 5))
          .thenThrow(Exception('boom'));
      final c = _container(repo);
      addTearDown(c.dispose);
      expect(
          await c
              .read(chatActionsProvider.notifier)
              .updateMaxParticipants('g1', 5),
          isFalse);
      expect(c.read(chatActionsProvider).status, ChatActionStatus.error);
    });
  });
}
