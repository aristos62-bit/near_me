import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'message_bubble.dart';

class ChatMessagesList extends ConsumerStatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final Map<String, String>? participantNicknames;

  const ChatMessagesList({
    super.key,
    required this.chatId,
    this.isGroupChat = false,
    this.participantNicknames,
  });

  @override
  ConsumerState<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends ConsumerState<ChatMessagesList> {
  final _scrollCtrl = ScrollController();
  int _lastMessageCount = 0;
  bool _hasMarkedRead = false;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatMessagesList init: ${widget.chatId}');
    Future.microtask(_markAsReadOnce);
  }

  @override
  void dispose() {
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatMessagesList dispose: ${widget.chatId}');
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markAsReadOnce() async {
    if (_hasMarkedRead) return;
    _hasMarkedRead = true;
    await ref.read(chatActionsProvider.notifier)
        .markAsRead(widget.chatId);
  }

  void _onMessagesChanged(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty || !mounted) return;
    if (messages.length == _lastMessageCount && !_isFirstLoad) return;
    final isNewMessage = messages.length > _lastMessageCount;
    _lastMessageCount = messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final maxScroll = _scrollCtrl.position.maxScrollExtent;
      if (_isFirstLoad) {
        _isFirstLoad = false;
        _scrollCtrl.jumpTo(maxScroll);
        return;
      }
      if (!isNewMessage) return;
      final currentScroll = _scrollCtrl.position.pixels;
      if ((maxScroll - currentScroll) > 50.0) {
        DebugConfig.log(DebugConfig.uiInteraction,
            'auto-scroll: suppressed (user ${(maxScroll - currentScroll).toInt()}px from bottom)');
        return;
      }
      _scrollCtrl.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final currentUid = ref.watch(authStateProvider).value?.uid ?? '';
    final greek = L10n.isGreek(context);

    return messagesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) {
        DebugConfig.error('ChatScreen messages error', data: e);
        return ErrorView(
          message: L10n.localizedMessage(context,
              'Σφάλμα φόρτωσης / Failed to load'),
          onRetry: () =>
              ref.invalidate(messagesProvider(widget.chatId)),
        );
      },
      data: (messages) {
        _onMessagesChanged(messages);
        if (messages.isEmpty) {
          return EmptyView(
            icon: Icons.chat_bubble_outline,
            message: greek ? 'Καμία συνομιλία' : 'No messages',
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = ResponsiveUtils.resolveWidth(context, constraints);
            return ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.paddingValueFromWidth(w),
                vertical: 8,
              ),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final senderId = messages[i]['senderId'] as String? ?? '';
                final nicknameMap = widget.participantNicknames;
                final senderNickname = widget.isGroupChat && nicknameMap != null
                    ? nicknameMap[senderId]
                    : null;
                return MessageBubble(
                  message: messages[i],
                  currentUid: currentUid,
                  isGroupChat: widget.isGroupChat,
                  senderNickname: senderNickname,
                  participantNicknames: widget.participantNicknames,
                );
              },
            );
          },
        );
      },
    );
  }
}
