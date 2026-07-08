import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/debug/debug_config.dart';
import '../core/notifications/fcm_service.dart';
import '../features/chat/providers/chat_provider.dart';
import '../features/requests/providers/requests_provider.dart';

final unreadBadgeProvider = Provider<int>((ref) {
  final chatUnread = ref.watch(chatsProvider).when(
    data: (list) => list.fold(0, (int sum, c) => sum + c.unreadCount),
    error: (_, _) => 0,
    loading: () => 0,
  );
  final requestUnread = ref.watch(unreadRequestsProvider);
  final total = chatUnread + requestUnread;
  FcmService.setBadge(total);
  DebugConfig.log(DebugConfig.chatFcm,
      'unreadBadgeProvider: total=$total (chats=$chatUnread, requests=$requestUnread)');
  return total;
});
