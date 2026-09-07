import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:near_me/data/local/database.dart';
import 'package:near_me/features/chat/providers/chat_provider.dart';
import 'package:near_me/features/requests/providers/requests_provider.dart';
import 'package:near_me/providers/unread_badge_provider.dart';

ChatCacheTableData _chat({required int id, required int unreadCount}) {
  return ChatCacheTableData(
    id: id,
    unreadCount: unreadCount,
    hasUnread: unreadCount > 0,
    isGroupChat: false,
    participantCount: 2,
    messageExpiry: 'never',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chats unread + request unread → sum', () async {
    final container = ProviderContainer(overrides: [
      chatsProvider.overrideWith(
        (ref) => Stream.value([
          _chat(id: 1, unreadCount: 3),
          _chat(id: 2, unreadCount: 1),
        ]),
      ),
      unreadRequestsProvider.overrideWith((ref) => 2),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(unreadBadgeProvider, (prev, next) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unreadBadgeProvider), 6);
    sub.close();
  });

  test('chats error stream → request-only fallback', () async {
    final container = ProviderContainer(overrides: [
      chatsProvider.overrideWith(
        (ref) => Stream.error(Exception('db failure')),
      ),
      unreadRequestsProvider.overrideWith((ref) => 4),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(unreadBadgeProvider, (prev, next) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unreadBadgeProvider), 4);
    sub.close();
  });

  test('chats empty + requests 0 → 0', () async {
    final container = ProviderContainer(overrides: [
      chatsProvider.overrideWith((ref) => Stream.value(const [])),
      unreadRequestsProvider.overrideWith((ref) => 0),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(unreadBadgeProvider, (prev, next) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unreadBadgeProvider), 0);
    sub.close();
  });

  test('all chats read + requests 1 → 1', () async {
    final container = ProviderContainer(overrides: [
      chatsProvider.overrideWith(
        (ref) => Stream.value([
          _chat(id: 1, unreadCount: 0),
          _chat(id: 2, unreadCount: 0),
        ]),
      ),
      unreadRequestsProvider.overrideWith((ref) => 1),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(unreadBadgeProvider, (prev, next) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unreadBadgeProvider), 1);
    sub.close();
  });

  test('mixed read/unread chats → correct sum', () async {
    final container = ProviderContainer(overrides: [
      chatsProvider.overrideWith(
        (ref) => Stream.value([
          _chat(id: 1, unreadCount: 0),
          _chat(id: 2, unreadCount: 5),
          _chat(id: 3, unreadCount: 2),
        ]),
      ),
      unreadRequestsProvider.overrideWith((ref) => 0),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(unreadBadgeProvider, (prev, next) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(unreadBadgeProvider), 7);
    sub.close();
  });
}
