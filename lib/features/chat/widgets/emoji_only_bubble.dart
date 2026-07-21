import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import 'message_action_bar.dart';
import 'message_bubble.dart';
import 'message_reactions.dart';
import '../../../shared/widgets/read_receipt_indicator.dart';

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
  static final _buildCounts = <String, int>{};
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
    _buildCounts[emojiMsgId] = (_buildCounts[emojiMsgId] ?? 0) + 1;
    final emojiBuildN = _buildCounts[emojiMsgId]!;
    DebugConfig.log(
      DebugConfig.chatBubbleDesign,
      'EmojiOnlyBubble: id=$emojiMsgId '
      '"${content.trim()}" fontSize=$fontSize '
      'isGrouped=$isGrouped isLastInGroup=$isLastInGroup build#$emojiBuildN',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && showAvatar
              && (senderAvatarUrl != null || (isGroupChat && senderNickname != null)))
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: senderAvatarUrl != null
                        ? CachedNetworkImageProvider(senderAvatarUrl!)
                        : null,
                    child: senderAvatarUrl == null && senderNickname != null
                        ? Text(senderNickname![0],
                            style: const TextStyle(fontSize: 18))
                        : null,
                  ),
                  if (isGroupChat && senderNickname != null) ...[
                    const SizedBox(width: 4),
                    Text(senderNickname!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (replyTo != null)
            ReplyPreview(
              replyTo: replyTo!,
              isMe: isMe,
              isGroupChat: isGroupChat,
            ),
          GestureDetector(
            onLongPressStart: (details) async {
              final result = await MessageActionBar.show(
                context: context,
                isOwn: isMe,
                globalPosition: details.globalPosition,
              );
              if (result == 'reply') onReply?.call();
              if (result == 'edit') onEdit?.call();
              if (result == 'delete') onDelete?.call();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      left: isMe ? 0 : 14,
                      right: isMe ? 14 : 0),
                  child: Text(
                    content.trim(),
                    textAlign: TextAlign.end,
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
          if (chatId != null && FeatureFlags.messageReactionsEnabled)
            MessageReactions(
              reactions: reactions,
              currentUid: currentUid,
              chatId: chatId!,
              messageId: messageId,
              isMe: isMe,
              onReact: onReact,
              onRemove: onRemove,
            ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 14),
              child: ReadReceiptIndicator(
                isGroupChat: isGroupChat,
                isMe: isMe,
                isRead: isRead,
                seenBy: seenBy,
              ),
            ),
        ],
      ),
    );
  }
}
