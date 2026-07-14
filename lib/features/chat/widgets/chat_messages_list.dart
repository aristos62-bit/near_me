import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String? otherUid;

  const ChatMessagesList({
    super.key,
    required this.chatId,
    this.isGroupChat = false,
    this.participantNicknames,
    this.otherUid,
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
  }

  @override
  void dispose() {
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatMessagesList dispose: ${widget.chatId}');
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onApproveDelete(String chatId) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatMessagesList: approveDelete chat=$chatId');
    await ref.read(chatActionsProvider.notifier).approveDeleteChat(chatId);
  }

  Future<void> _onRejectDelete(String chatId) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatMessagesList: rejectDelete chat=$chatId');
    await ref.read(chatActionsProvider.notifier).rejectDeleteChat(chatId);
  }

  Future<void> _onDeleteForMe(String chatId) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatMessagesList: deleteForMe chat=$chatId');
    await ref.read(chatActionsProvider.notifier).deleteChatForMe(chatId);
  }

  Future<void> _onKeepChat(String chatId) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'ChatMessagesList: keepChat chat=$chatId');
    await ref.read(chatActionsProvider.notifier).cancelDeleteRequest(chatId);
  }

  void _onMessagesChanged(List<Map<String, dynamic>> messages) {
    if (!_hasMarkedRead) {
      _hasMarkedRead = true;
      Future.microtask(() {
        if (mounted) {
          ref.read(chatActionsProvider.notifier)
              .markAsRead(widget.chatId, isGroupChat: widget.isGroupChat);
        }
      });
    }
    if (messages.isEmpty || !mounted) return;
    if (messages.length == _lastMessageCount && !_isFirstLoad) return;
    final isNewMessage = messages.length > _lastMessageCount;
    _lastMessageCount = messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (_isFirstLoad) {
        _isFirstLoad = false;
        _scrollCtrl.jumpTo(0);
        return;
      }
      if (!isNewMessage) return;
      final currentScroll = _scrollCtrl.position.pixels;
      if (currentScroll > 50.0) {
        DebugConfig.log(DebugConfig.uiInteraction,
            'auto-scroll: suppressed (user ${currentScroll.toInt()}px from bottom)');
        return;
      }
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final currentUid = ref.watch(authStateProvider).value?.uid ?? '';
    final chatDocAsync = ref.watch(chatDocProvider(widget.chatId));
    final greek = L10n.isGreek(context);

    Map<String, DateTime> lastReadTimestamps = {};
    final chatData = chatDocAsync.asData?.value?.data() as Map<String, dynamic>?;
    final raw = chatData?['lastReadTimestamps'] as Map<String, dynamic>?;
    if (raw != null) {
      lastReadTimestamps = raw.map((k, v) {
        final ts = (v as Timestamp?)?.toDate();
        return MapEntry(k, ts ?? DateTime(2020));
      });
    }

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
              reverse: true,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.paddingValueFromWidth(w),
                vertical: 8,
              ),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[messages.length - 1 - i];
                final senderId = msg['senderId'] as String? ?? '';
                final msgTimestamp = (msg['timestamp'] as Timestamp?)?.toDate();
                final nicknameMap = widget.participantNicknames;
                final senderNickname = widget.isGroupChat && nicknameMap != null
                    ? nicknameMap[senderId]
                    : null;
                if (widget.isGroupChat && senderNickname == null) {
                  DebugConfig.warn(
                      'ChatMessagesList: senderNickname null for senderId=$senderId '
                      'chat=${widget.chatId} nicknameMapSize=${nicknameMap?.length ?? 0}');
                }

                List<String> seenBy = [];
                if (widget.isGroupChat && msgTimestamp != null) {
                  seenBy = lastReadTimestamps.entries
                      .where((e) => e.key != senderId && e.value.compareTo(msgTimestamp) >= 0)
                      .map((e) => e.key)
                      .toList();
                }

                final bool effectiveIsRead;
                if (widget.isGroupChat) {
                  effectiveIsRead = false;
                } else {
                  final msgIsRead = msg['isRead'] as bool? ?? false;
                  final otherLastRead = widget.otherUid != null ? lastReadTimestamps[widget.otherUid] : null;
                  effectiveIsRead = msgIsRead || (otherLastRead != null && msgTimestamp != null && otherLastRead.compareTo(msgTimestamp) >= 0);
                }

                return MessageBubble(
                  message: msg,
                  currentUid: currentUid,
                  isGroupChat: widget.isGroupChat,
                  isRead: effectiveIsRead,
                  senderNickname: senderNickname,
                  participantNicknames: widget.participantNicknames,
                  seenBy: seenBy,
                  chatId: widget.chatId,
                  onApproveDelete: _onApproveDelete,
                  onRejectDelete: _onRejectDelete,
                  onDeleteForMe: _onDeleteForMe,
                  onKeepChat: _onKeepChat,
                );
              },
            );
          },
        );
      },
    );
  }
}
