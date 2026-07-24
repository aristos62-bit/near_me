import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import 'message_bubble/reply_preview.dart';
import 'message_bubble/sender_header.dart';
import 'message_bubble/bubble_long_press_wrapper.dart';
import 'message_bubble/message_reactions_row.dart';
import 'message_bubble/read_receipt_footer.dart';

final _emojiRegex = RegExp(EmojiRegex, unicode: true);
// ignore: valid_regexps
final _emojiCharRegex = RegExp(r'\p{Emoji}', unicode: true);
final _riRegex = RegExp(r'\p{Regional_Indicator}', unicode: true);

bool isOnlyEmoji(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  return trimmed.replaceAll(_emojiRegex, '').trim().isEmpty;
}

double emojiFontSize(String text) {
  final total = _emojiCharRegex.allMatches(text).length;
  final riPairs = _riRegex.allMatches(text).length ~/ 2;
  final effective = total - riPairs;
  if (effective <= 1) return 55;
  if (effective <= 3) return 40;
  if (effective <= 6) return 30;
  return 28;
}

class EmojiOnlyBubble extends StatelessWidget {
  final String content;
  final String timeStr;
  final bool isMe;
  final bool isGroupChat;
  final bool isGrouped;
  final bool isLastInGroup;
  final bool showAvatar;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final List<String> seenBy;
  final bool isRead;
  final String? chatId;
  final String currentUid;
  final String messageId;
  final Map<String, dynamic> reactions;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EmojiOnlyBubble({
    super.key,
    required this.content,
    required this.timeStr,
    required this.isMe,
    this.isGroupChat = false,
    this.isGrouped = false,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.senderNickname,
    this.senderAvatarUrl,
    this.seenBy = const [],
    this.isRead = false,
    this.chatId,
    this.currentUid = '',
    this.messageId = '',
    this.reactions = const {},
    this.onReact,
    this.onRemove,
    this.replyTo,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize = emojiFontSize(content);
    final textColor = isMe
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface;

    final emojiMsgId = messageId;
    DebugConfig.log(
      DebugConfig.chatBubbleDesign,
      'EmojiOnlyBubble: id=$emojiMsgId '
          '"${content.trim()}" fontSize=$fontSize '
          'isGrouped=$isGrouped isLastInGroup=$isLastInGroup',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && showAvatar
              && (senderAvatarUrl != null || senderNickname != null))
            SenderHeader(
              senderAvatarUrl: senderAvatarUrl,
              senderNickname: senderNickname,
              isGroupChat: isGroupChat,
            ),
          if (replyTo != null)
            ReplyPreview(
              replyTo: replyTo!,
              isMe: isMe,
              isGroupChat: isGroupChat,
            ),
          BubbleLongPressWrapper(
            isMe: isMe,
            onReply: onReply,
            onEdit: onEdit,
            onDelete: onDelete,
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      left: isMe ? 0 : 14,
                      right: isMe ? 14 : 0),
                  child: Text(
                    content.trim(),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                        top: 2,
                        left: isMe ? 0 : 14,
                        right: isMe ? 14 : 0),
                    child: Text(timeStr,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          MessageReactionsRow(
            chatId: chatId,
            reactions: reactions,
            currentUid: currentUid,
            messageId: messageId,
            isMe: isMe,
            onReact: onReact,
            onRemove: onRemove,
          ),
          ReadReceiptFooter(
            isMe: isMe,
            isGroupChat: isGroupChat,
            isRead: isRead,
            seenBy: seenBy,
          ),
        ],
      ),
    );
  }
}
