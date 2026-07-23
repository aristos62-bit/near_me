import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/debug/debug_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../emoji_only_bubble.dart';
import 'message_callbacks.dart';
import 'system_message_bubble.dart';
import 'gif_image_bubble.dart';
import 'text_message_bubble.dart';

class MessageBubble extends StatelessWidget {
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
  final String? chatId;
  final MessageCallbacks callbacks;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUid,
    this.isGroupChat = false,
    this.isRead = false,
    this.isGrouped = false,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.senderNickname,
    this.senderAvatarUrl,
    this.participantNicknames,
    this.seenBy = const [],
    this.chatId,
    this.callbacks = const MessageCallbacks(),
  });

  @override
  Widget build(BuildContext context) {
    final type = message['type'] as String? ?? 'text';
    final content = message['content'] as String? ?? '';
    final senderId = message['senderId'] as String? ?? '';
    final timestamp = message['timestamp'] as dynamic;
    final ts = timestamp is Timestamp ? timestamp.toDate() : null;
    final timeStr = ts != null
        ? L10n.formatTimeOfDay(context, TimeOfDay.fromDateTime(ts))
        : '';
    final reactions = (message['reactions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final replyTo = message['replyTo'] as Map<String, dynamic>?;
    final msgId = message['id'] as String? ?? '';
    final isMe = senderId == currentUid;
    final contentEn = message['contentEn'] as String?;
    final action = message['action'] as String?;
    final mentions = (message['mentions'] as List?)?.cast<String>() ?? <String>[];

    DebugConfig.log(DebugConfig.chatBubbleDesign,
        'MessageBubble: type=$type id=$msgId');

    return switch (type) {
      'system' => SystemMessageBubble(
        content: content,
        contentEn: contentEn,
        timeStr: timeStr,
        action: action,
        isRequester: isMe,
        chatId: chatId,
        onApproveDelete: callbacks.onApproveDelete,
        onRejectDelete: callbacks.onRejectDelete,
        onDeleteForMe: callbacks.onDeleteForMe,
        onKeepChat: callbacks.onKeepChat,
      ),
      'gif' || 'image' => GifImageBubble(
        content: content,
        timeStr: timeStr,
        isMe: isMe,
        isGroupChat: isGroupChat,
        isGrouped: isGrouped,
        isLastInGroup: isLastInGroup,
        showAvatar: showAvatar,
        senderNickname: senderNickname,
        senderAvatarUrl: senderAvatarUrl,
        seenBy: seenBy,
        isRead: isRead,
        chatId: chatId,
        currentUid: currentUid,
        messageId: msgId,
        isImage: type == 'image',
        reactions: reactions,
        onReact: callbacks.onReact,
        onRemove: callbacks.onRemove,
        replyTo: replyTo,
        onReply: callbacks.onReply,
        onEdit: callbacks.onEdit,
        onDelete: callbacks.onDelete,
      ),
      _ when type == 'text' && isOnlyEmoji(content) => EmojiOnlyBubble(
        content: content,
        timeStr: timeStr,
        isMe: isMe,
        isGroupChat: isGroupChat,
        isGrouped: isGrouped,
        isLastInGroup: isLastInGroup,
        showAvatar: showAvatar,
        senderNickname: senderNickname,
        senderAvatarUrl: senderAvatarUrl,
        seenBy: seenBy,
        isRead: isRead,
        chatId: chatId,
        currentUid: currentUid,
        messageId: msgId,
        reactions: reactions,
        onReact: callbacks.onReact,
        onRemove: callbacks.onRemove,
        replyTo: replyTo,
        onReply: callbacks.onReply,
        onEdit: callbacks.onEdit,
        onDelete: callbacks.onDelete,
      ),
      _ => TextMessageBubble(
        content: content,
        timeStr: timeStr,
        isMe: isMe,
        isGroupChat: isGroupChat,
        isGrouped: isGrouped,
        isLastInGroup: isLastInGroup,
        showAvatar: showAvatar,
        senderNickname: senderNickname,
        senderAvatarUrl: senderAvatarUrl,
        seenBy: seenBy,
        isRead: isRead,
        chatId: chatId,
        currentUid: currentUid,
        messageId: msgId,
        reactions: reactions,
        onReact: callbacks.onReact,
        onRemove: callbacks.onRemove,
        replyTo: replyTo,
        mentions: mentions,
        participantNicknames: participantNicknames,
        onReply: callbacks.onReply,
        onEdit: callbacks.onEdit,
        onDelete: callbacks.onDelete,
      ),
    };
  }
}
