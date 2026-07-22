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

class _MessageReadProps {
  final bool effectiveIsRead;
  final List<String> seenBy;
  const _MessageReadProps({required this.effectiveIsRead, required this.seenBy});
}

/// Αποθηκεύει τις τιμές με τις οποίες χτίστηκε μια MessageBubble, ώστε να
/// μπορούμε να συγκρίνουμε (plain Dart equality, όχι Widget.==) αν κάτι
/// άλλαξε πραγματικά πριν φτιάξουμε νέο instance.
class _MessageBubbleSignature {
  final Map<String, dynamic> message;
  final String currentUid;
  final bool isGroupChat;
  final bool isRead;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final Map<String, String>? participantNicknames;
  final List<String> seenBy;
  final double bubbleMaxWidth;

  const _MessageBubbleSignature({
    required this.message,
    required this.currentUid,
    required this.isGroupChat,
    required this.isRead,
    required this.isGrouped,
    required this.isLastInGroup,
    required this.showAvatar,
    required this.senderNickname,
    required this.senderAvatarUrl,
    required this.participantNicknames,
    required this.seenBy,
    required this.bubbleMaxWidth,
  });

  bool matches({
    required Map<String, dynamic> message,
    required String currentUid,
    required bool isGroupChat,
    required bool isRead,
    required bool isGrouped,
    required bool isLastInGroup,
    required bool showAvatar,
    required String? senderNickname,
    required String? senderAvatarUrl,
    required Map<String, String>? participantNicknames,
    required List<String> seenBy,
    required double bubbleMaxWidth,
  }) {
    return currentUid == this.currentUid &&
        isGroupChat == this.isGroupChat &&
        isRead == this.isRead &&
        isGrouped == this.isGrouped &&
        isLastInGroup == this.isLastInGroup &&
        showAvatar == this.showAvatar &&
        senderNickname == this.senderNickname &&
        senderAvatarUrl == this.senderAvatarUrl &&
        bubbleMaxWidth == this.bubbleMaxWidth &&
        const ListEquality<String>().equals(seenBy, this.seenBy) &&
        const DeepCollectionEquality()
            .equals(participantNicknames, this.participantNicknames) &&
        const DeepCollectionEquality().equals(message, this.message);
  }
}

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
  bool _isFirstLoad = true;
  double _lastScrollLogPixels = 0;
  Stopwatch? _scrollBurstStopwatch;
  int _buildCount = 0;
  Map<String, DateTime>? _lastLastReadTimestamps;
  final Map<String, MessageBubble> _bubbleCache = {};
  final Map<String, _MessageBubbleSignature> _bubbleSignatures = {};

  MessageBubble _obtainBubble({
    required String msgId,
    required Map<String, dynamic> message,
    required double bubbleMaxWidth,
    required String currentUid,
    required bool isGroupChat,
    required bool isRead,
    required bool isGrouped,
    required bool isLastInGroup,
    required bool showAvatar,
    required String? senderNickname,
    required String? senderAvatarUrl,
    required Map<String, String>? participantNicknames,
    required List<String> seenBy,
    required String chatId,
  }) {
    final existingSig = _bubbleSignatures[msgId];
    if (existingSig != null &&
        existingSig.matches(
          message: message,
          currentUid: currentUid,
          isGroupChat: isGroupChat,
          isRead: isRead,
          isGrouped: isGrouped,
          isLastInGroup: isLastInGroup,
          showAvatar: showAvatar,
          senderNickname: senderNickname,
          senderAvatarUrl: senderAvatarUrl,
          participantNicknames: participantNicknames,
          seenBy: seenBy,
          bubbleMaxWidth: bubbleMaxWidth,
        )) {
      final cached = _bubbleCache[msgId]!;
      DebugConfig.log(DebugConfig.chatBubbleDesign,
          'MSG_LIST: cache HIT id=$msgId '
          'identity=${identityHashCode(cached)} '
          'bubbleMaxWidth=$bubbleMaxWidth');
      return cached;
    }
    DebugConfig.log(DebugConfig.chatBubbleDesign,
        'MSG_LIST: cache MISS id=$msgId '
        'existingSig=${existingSig != null} '
        'bubbleMaxWidth=$bubbleMaxWidth');
    final bubble = MessageBubble(
      key: ValueKey(msgId),
      bubbleMaxWidth: bubbleMaxWidth,
      message: message,
      currentUid: currentUid,
      isGroupChat: isGroupChat,
      isRead: isRead,
      isGrouped: isGrouped,
      isLastInGroup: isLastInGroup,
      showAvatar: showAvatar,
      senderNickname: senderNickname,
      senderAvatarUrl: senderAvatarUrl,
      participantNicknames: participantNicknames,
      seenBy: seenBy,
      chatId: chatId,
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

    _bubbleCache[msgId] = bubble;
    _bubbleSignatures[msgId] = _MessageBubbleSignature(
      message: message,
      currentUid: currentUid,
      isGroupChat: isGroupChat,
      isRead: isRead,
      isGrouped: isGrouped,
      isLastInGroup: isLastInGroup,
      showAvatar: showAvatar,
      senderNickname: senderNickname,
      senderAvatarUrl: senderAvatarUrl,
      participantNicknames: participantNicknames,
      seenBy: seenBy,
      bubbleMaxWidth: bubbleMaxWidth,
    );
    return bubble;
  }

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
    final screenW = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).textScaleFactor;
    DebugConfig.log(DebugConfig.chatBubbleDesign,
        'MSG_LIST BUILD #$_buildCount chat=${widget.chatId} '
        'screenW=${screenW.toStringAsFixed(1)} textScale=${textScale.toStringAsFixed(2)}');

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
        final currentIds = messages
            .map((m) => m['id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        _bubbleCache.removeWhere((id, _) => !currentIds.contains(id));
        _bubbleSignatures.removeWhere((id, _) => !currentIds.contains(id));
        _onMessagesChanged(messages);
        if (messages.isEmpty) {
          return EmptyView(
            icon: Icons.chat_bubble_outline,
            message: greek ? 'Καμία συνομιλία' : 'No messages',
          );
        }
        final renderItems = ChatGroupingCalculator.calculate(widget.chatId, messages, currentUid);
        final readProps = _precomputeReadProps(
          messages,
          currentUid,
          widget.otherUid,
          lastReadTimestamps,
          widget.isGroupChat,
        );
        final w = MediaQuery.sizeOf(context).width;
        final bubbleMaxWidth = w * 0.75;
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

            final msgId = msg['id'] as String? ?? '';
            final props = readProps[msgId] ??
                const _MessageReadProps(effectiveIsRead: false, seenBy: []);

            return _obtainBubble(
              msgId: msgId,
              message: msg,
              bubbleMaxWidth: bubbleMaxWidth,
              currentUid: currentUid,
              isGroupChat: widget.isGroupChat,
              isRead: props.effectiveIsRead,
              isGrouped: item.isGrouped,
              isLastInGroup: item.isLastInGroup,
              showAvatar: item.showAvatar,
              senderNickname: senderNickname,
              senderAvatarUrl: senderAvatarUrl,
              participantNicknames: widget.participantNicknames,
              seenBy: props.seenBy,
              chatId: widget.chatId,
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