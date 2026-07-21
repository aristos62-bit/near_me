import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/chat_ui_utils.dart';
import 'date_separator.dart';
import 'message_bubble.dart';

class ChatMessagesList extends ConsumerStatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final Map<String, String>? participantNicknames;
  final Map<String, String>? participantAvatarUrls;
  final String? otherUid;

  const ChatMessagesList({
    super.key,
    required this.chatId,
    this.isGroupChat = false,
    this.participantNicknames,
    this.participantAvatarUrls,
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
  double _lastScrollLogPixels = 0;
  Stopwatch? _scrollBurstStopwatch;
  int _buildCount = 0;
  Map<String, DateTime>? _lastLastReadTimestamps;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatMessagesList init: ${widget.chatId}');
    _scrollCtrl.addListener(() {
      final pixels = _scrollCtrl.position.pixels;
      if ((pixels - _lastScrollLogPixels).abs() > 10.0) {
        _lastScrollLogPixels = pixels;
        _scrollBurstStopwatch ??= Stopwatch()..start();
        DebugConfig.log(DebugConfig.uiInteraction,
            'SCROLL: pixels=$pixels elapsed=${_scrollBurstStopwatch!.elapsedMilliseconds}ms');
        if (_scrollBurstStopwatch!.elapsedMilliseconds > 500) {
          _scrollBurstStopwatch?.stop();
          _scrollBurstStopwatch = null;
        }
      }
    });
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

  Future<void> _onReact(String messageId, String emoji) async {
    DebugConfig.log(DebugConfig.chatReactions, 'ChatMessagesList: react msg=$messageId emoji=$emoji');
    await ref.read(chatActionsProvider.notifier).reactToMessage(widget.chatId, messageId, emoji);
  }

  Future<void> _onRemove(String messageId) async {
    DebugConfig.log(DebugConfig.chatReactions, 'ChatMessagesList: remove reaction msg=$messageId');
    await ref.read(chatActionsProvider.notifier).removeReaction(widget.chatId, messageId);
  }

  void _onReply(Map<String, dynamic> msg) {
    DebugConfig.log(DebugConfig.chatReply, 'ChatMessagesList: reply msg=${msg['id']}');
    ref.read(replyToMessageProvider.notifier).setReply(msg);
  }

  void _onEdit(Map<String, dynamic> msg) {
    DebugConfig.log(DebugConfig.chatReply, 'ChatMessagesList: edit msg=${msg['id']}');
    ref.read(editingMessageProvider.notifier).setEdit(msg);
  }

  Future<void> _onDelete(Map<String, dynamic> msg) async {
    final messageId = msg['id'] as String? ?? '';
    if (messageId.isEmpty) return;
    if (!mounted) return;
    final greek = L10n.isGreek(context);
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: greek ? 'Διαγραφή μηνύματος' : 'Delete message',
      message: greek ? 'Θέλεις να διαγράψεις αυτό το μήνυμα;' : 'Delete this message?',
      confirmLabel: greek ? 'Διαγραφή' : 'Delete',
      cancelLabel: greek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );
    if (!mounted || confirmed != true) return;
    DebugConfig.log(DebugConfig.chatReply, 'ChatMessagesList: delete msg=$messageId');
    await ref.read(chatActionsProvider.notifier).deleteMessage(widget.chatId, messageId);
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
    final lastReadTimestamps = ref.watch(chatDocProvider(widget.chatId).select((a) {
      final raw = (a.asData?.value?.data() as Map<String, dynamic>?)
          ?['lastReadTimestamps'] as Map<String, dynamic>?;
      if (raw == null) return const <String, DateTime>{};
      final result = raw.map((k, v) {
        final ts = (v as Timestamp?)?.toDate();
        return MapEntry(k, ts ?? DateTime(2020));
      });
      if (_lastLastReadTimestamps != null &&
          const DeepCollectionEquality().equals(_lastLastReadTimestamps, result)) {
        DebugConfig.log(DebugConfig.chatStream,
            'ChatMessagesList: lastReadTimestamps cache hit for ${widget.chatId}');
        return _lastLastReadTimestamps!;
      }
      DebugConfig.log(DebugConfig.chatStream,
          'ChatMessagesList: lastReadTimestamps cache miss for ${widget.chatId}');
      _lastLastReadTimestamps = result;
      return result;
    }));
    final greek = L10n.isGreek(context);
    _buildCount++;
    if (_buildCount > 1) {
      DebugConfig.log(DebugConfig.uiInteraction,
          'ChatMessagesList BUILD #$_buildCount');
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
        final renderItems = ChatGroupingCalculator.calculate(messages, currentUid);
        final w = MediaQuery.sizeOf(context).width;
        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.paddingValueFromWidth(w),
            vertical: 8,
          ),
          itemCount: renderItems.length,
          itemBuilder: (_, i) {
                final item = renderItems[renderItems.length - 1 - i];
                if (item.type == RenderItemType.dateSeparator) {
                  return DateSeparator(key: ValueKey('ds_${item.date}'), date: item.date!);
                }

                final msg = item.message!;
                final senderId = msg['senderId'] as String? ?? '';
                final msgTimestamp = (msg['timestamp'] as Timestamp?)?.toDate();
                final nicknameMap = widget.participantNicknames;
                final senderNickname = widget.isGroupChat && nicknameMap != null
                    ? nicknameMap[senderId]
                    : null;
                final avatarUrls = widget.participantAvatarUrls;
                final senderAvatarUrl = avatarUrls != null
                    ? avatarUrls[senderId]
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

                if (!widget.isGroupChat && senderId == currentUid) {
                  final dbgMsgIsRead = msg['isRead'] as bool? ?? false;
                  final dbgOtherUid = widget.otherUid;
                  final dbgOtherLT = dbgOtherUid != null ? lastReadTimestamps[dbgOtherUid] : null;
                  DebugConfig.log(DebugConfig.chatBubbleDesign,
                      'effectiveIsRead: msgIsRead=$dbgMsgIsRead otherLastRead=$dbgOtherLT '
                      'msgTs=$msgTimestamp effective=$effectiveIsRead');
                }

              return MessageBubble(
                key: ValueKey(msg['id'] as String? ?? ''),
                message: msg,
                  currentUid: currentUid,
                  isGroupChat: widget.isGroupChat,
                  isRead: effectiveIsRead,
                  isGrouped: item.isGrouped,
                  isLastInGroup: item.isLastInGroup,
                  showAvatar: item.showAvatar,
                  senderNickname: senderNickname,
                  senderAvatarUrl: senderAvatarUrl,
                  participantNicknames: widget.participantNicknames,
                  seenBy: seenBy,
                  chatId: widget.chatId,
                  onApproveDelete: _onApproveDelete,
                  onRejectDelete: _onRejectDelete,
                  onDeleteForMe: _onDeleteForMe,
                  onKeepChat: _onKeepChat,
                  onReact: _onReact,
                  onRemove: _onRemove,
                  onReply: _onReply,
                  onEdit: _onEdit,
                  onDelete: _onDelete,
                );
              },
            );
      },
    );
  }
}
