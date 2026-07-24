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
import 'message_bubble/message_bubble.dart';
import 'message_bubble/message_callbacks.dart';

class _MessageReadProps {
  final bool effectiveIsRead;
  final List<String> seenBy;
  const _MessageReadProps({required this.effectiveIsRead, required this.seenBy});
}

class ChatMessagesList extends ConsumerStatefulWidget {
  final String chatId;

  const ChatMessagesList({
    super.key,
    required this.chatId,
  });

  @override
  ConsumerState<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends ConsumerState<ChatMessagesList> {
  final _scrollCtrl = ScrollController();
  int _lastMessageCount = 0;
  bool _isFirstLoad = true;
  int _buildCount = 0;
  Map<String, DateTime>? _lastLastReadTimestamps;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction,
        'ChatMessagesList init: ${widget.chatId}');
    _scrollCtrl.addListener(() {
      final pixels = _scrollCtrl.position.pixels;
      if (_scrollCtrl.position.maxScrollExtent - pixels < 300) {
        _maybeLoadOlder();
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

  static const _editWindow = Duration(minutes: 15);

  void _onEdit(Map<String, dynamic> msg) {
    DebugConfig.log(DebugConfig.chatReply, 'ChatMessagesList: edit msg=${msg['id']}');
    final rawTs = msg['timestamp'];
    final ts = rawTs is Timestamp ? rawTs.toDate() : null;
    if (ts != null && DateTime.now().difference(ts) > _editWindow) {
      final greek = L10n.isGreek(context);
      AppMessenger.showInfo(
        context,
        greek
            ? 'Το χρονικό όριο επεξεργασίας (15 λεπτά) έχει λήξει'
            : 'The 15-minute edit window has expired',
      );
      return;
    }
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

  void _maybeLoadOlder() {
    final current = ref.read(combinedMessagesProvider(widget.chatId));
    if (current.isEmpty) return;
    final oldest = current.first;
    final rawTs = oldest['timestamp'];
    if (rawTs is! Timestamp) return;
    ref.read(olderMessagesByChatProvider.notifier).loadMore(widget.chatId, rawTs.toDate());
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
    final isGroupChat = ref.watch(chatDocProvider(widget.chatId).select(
      (a) =>
          (a.asData?.value?.data() as Map<String, dynamic>?)?['isGroupChat'] ==
          true,
    ));
    final participantNicknames = ref.watch(chatDocProvider(widget.chatId).select(
      (a) {
        final raw = (a.asData?.value?.data() as Map<String, dynamic>?)
            ?['participantNicknames'] as Map<String, dynamic>?;
        if (raw == null) return const <String, String>{};
        return raw.map((k, v) => MapEntry(k, v as String? ?? k));
      },
    ));
    final participantAvatarUrls = ref.watch(chatDocProvider(widget.chatId).select(
      (a) {
        final raw = (a.asData?.value?.data() as Map<String, dynamic>?)
            ?['participantAvatarUrls'] as Map<String, dynamic>?;
        if (raw == null) return const <String, String>{};
        return raw.map((k, v) => MapEntry(k, v as String? ?? ''));
      },
    ));
    final participantUids = ref.watch(participantUidsProvider(widget.chatId));
    final otherUid = isGroupChat ? null : participantUids.where((u) => u != currentUid).firstOrNull;
    // --- ΝΕΟ: combined (παλιά + live) λίστα για rendering + loading state παλιών μηνυμάτων ---
    final combinedMessages = ref.watch(combinedMessagesProvider(widget.chatId));
    final isLoadingOlder = ref.watch(olderMessagesByChatProvider
        .select((m) => m[widget.chatId]?.isLoading ?? false));
    final greek = L10n.isGreek(context);
    _buildCount++;
    final screenW = MediaQuery.sizeOf(context).width;
    DebugConfig.log(DebugConfig.chatBubbleDesign,
        'MSG_LIST BUILD #$_buildCount chat=${widget.chatId} '
        'screenW=${screenW.toStringAsFixed(1)}');

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
        // _onMessagesChanged οδηγείται από το live window (όχι το combined),
        // ώστε το auto-scroll-to-bottom να ενεργοποιείται ΜΟΝΟ από νέα μηνύματα
        // και όχι από τη φόρτωση παλιότερων (που δεν πρέπει να προκαλεί scroll).
        _onMessagesChanged(messages);
        if (combinedMessages.isEmpty) {
          return EmptyView(
            icon: Icons.chat_bubble_outline,
            message: greek ? 'Καμία συνομιλία' : 'No messages',
          );
        }
        final renderItems = ChatGroupingCalculator.calculate(widget.chatId, combinedMessages, currentUid);
        final readProps = _precomputeReadProps(
          combinedMessages,
          currentUid,
          otherUid,
          lastReadTimestamps,
          isGroupChat,
        );
        final totalWithReactions = combinedMessages.where((m) {
          final r = m['reactions'] as Map<String, dynamic>?;
          return r != null && r.isNotEmpty;
        }).length;
        final totalRead = readProps.values.where((p) => p.effectiveIsRead).length;
        final totalWithSeenBy = readProps.values.where((p) => p.seenBy.isNotEmpty).length;
        DebugConfig.log(DebugConfig.chatBubbleDesign,
            'MSG_LIST: ${renderItems.length} items, '
            '${combinedMessages.length} msgs, '
            '$totalWithReactions with reactions, '
            '$totalRead read, '
            '$totalWithSeenBy with seenBy');
        // --- ΝΕΟ: +1 item στην κορυφή (μεγαλύτερο index, λόγω reverse:true) όσο φορτώνονται παλιά μηνύματα ---
        final itemCount = renderItems.length + (isLoadingOlder ? 1 : 0);
        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.paddingValueFromWidth(
                MediaQuery.sizeOf(context).width),
            vertical: 8,
          ),
          itemCount: itemCount,
          itemBuilder: (_, i) {
            if (isLoadingOlder && i == itemCount - 1) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final item = renderItems[renderItems.length - 1 - i];
            if (item.type == RenderItemType.dateSeparator) {
              return DateSeparator(key: ValueKey('ds_${item.date}'), date: item.date!);
            }

            final msg = item.message!;
            final senderId = msg['senderId'] as String? ?? '';
            final senderNickname = participantNicknames[senderId];
            final senderAvatarUrl = participantAvatarUrls[senderId];
            if (senderNickname == null) {
              DebugConfig.warn(
                  'ChatMessagesList: senderNickname null for senderId=$senderId '
                      'chat=${widget.chatId} nicknameMapSize=${participantNicknames.length}');
            }

            final msgId = msg['id'] as String? ?? '';
            final props = readProps[msgId] ??
                const _MessageReadProps(effectiveIsRead: false, seenBy: []);

            return MessageBubble(
              key: ValueKey(msgId),
              message: msg,
              currentUid: currentUid,
              isGroupChat: isGroupChat,
              isRead: props.effectiveIsRead,
              isGrouped: item.isGrouped,
              isLastInGroup: item.isLastInGroup,
              showAvatar: item.showAvatar,
              senderNickname: senderNickname,
              senderAvatarUrl: senderAvatarUrl,
              participantNicknames: isGroupChat ? participantNicknames : null,
              seenBy: props.seenBy,
              chatId: widget.chatId,
              callbacks: MessageCallbacks(
                onApproveDelete: _onApproveDelete,
                onRejectDelete: _onRejectDelete,
                onDeleteForMe: _onDeleteForMe,
                onKeepChat: _onKeepChat,
                onReact: _onReact,
                onRemove: _onRemove,
                onReply: () => _onReply(msg),
                onEdit: () => _onEdit(msg),
                onDelete: () => _onDelete(msg),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, _MessageReadProps> _precomputeReadProps(
      List<Map<String, dynamic>> messages,
      String currentUid,
      String? otherUid,
      Map<String, DateTime> lastReadTimestamps,
      bool isGroupChat,
      ) {
    final result = <String, _MessageReadProps>{};
    for (final msg in messages) {
      final msgId = msg['id'] as String? ?? '';
      if (msgId.isEmpty) continue;
      final senderId = msg['senderId'] as String? ?? '';
      final rawTs = msg['timestamp'];
      final msgTimestamp = rawTs is Timestamp ? rawTs.toDate() : null;

      List<String> seenBy;
      if (isGroupChat && msgTimestamp != null) {
        seenBy = lastReadTimestamps.entries
            .where((e) => e.key != senderId && e.value.compareTo(msgTimestamp) >= 0)
            .map((e) => e.key)
            .toList();
      } else {
        seenBy = [];
      }

      bool effectiveIsRead;
      if (isGroupChat) {
        effectiveIsRead = false;
      } else {
        final msgIsRead = msg['isRead'] as bool? ?? false;
        final otherLastRead = otherUid != null ? lastReadTimestamps[otherUid] : null;
        effectiveIsRead = msgIsRead ||
            (otherLastRead != null &&
                msgTimestamp != null &&
                otherLastRead.compareTo(msgTimestamp) >= 0);
      }

      result[msgId] = _MessageReadProps(
        effectiveIsRead: effectiveIsRead,
        seenBy: seenBy,
      );
    }
    DebugConfig.log(DebugConfig.chatBubbleDesign,
        'ChatMessagesList: precomputed ${result.length} readProps for ${messages.length} msgs');
    return result;
  }
}
