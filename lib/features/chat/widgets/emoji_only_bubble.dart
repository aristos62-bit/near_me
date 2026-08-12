import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'message_bubble/reply_preview.dart';
import 'message_bubble/sender_header.dart';
import 'message_bubble/bubble_long_press_wrapper.dart';

import 'message_reactions.dart';
import 'message_bubble/read_receipt_footer.dart';
import 'message_bubble/tail_painter.dart';
import '../../../core/theme/app_colors.dart';

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
  final double bubbleMaxWidth;
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
  final VoidCallback? onInfo;
  final VoidCallback? onEmail;
  final VoidCallback? onShare;

  const EmojiOnlyBubble({
    super.key,
    required this.content,
    required this.bubbleMaxWidth,
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
    this.onInfo,
    this.onEmail,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final hasQuote = replyTo != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe &&
              showAvatar &&
              (senderAvatarUrl != null || senderNickname != null))
            SenderHeader(
              senderAvatarUrl: senderAvatarUrl,
              senderNickname: senderNickname,
              isGroupChat: isGroupChat,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isMe)
                ReactionTriggerIcon(
                  chatId: chatId,
                  messageId: messageId,
                  reactions: reactions,
                  currentUid: currentUid,
                  isMe: isMe,
                  onReact: onReact,
                  onRemove: onRemove,
                ),
              BubbleLongPressWrapper(
                isMe: isMe,
                onReply: onReply,
                onEdit: onEdit,
                onDelete: onDelete,
                onInfo: onInfo,
                onEmail: onEmail,
                onShare: onShare,
                child: hasQuote ? _buildQuoteCard(context) : _buildBare(context),
              ),
              if (!isMe)
                ReactionTriggerIcon(
                  chatId: chatId,
                  messageId: messageId,
                  reactions: reactions,
                  currentUid: currentUid,
                  isMe: isMe,
                  onReact: onReact,
                  onRemove: onRemove,
                ),
            ],
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

  Widget _buildBare(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize = emojiFontSize(content);
    final textColor = theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: isMe ? 0 : 14,
            right: isMe ? 14 : 0,
          ),
          child: Text(
            content.trim(),
            textAlign: TextAlign.start,
            style: TextStyle(fontSize: fontSize, color: textColor),
          ),
        ),
        if (timeStr.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              left: isMe ? 0 : 14,
              right: isMe ? 14 : 0,
            ),
            child: Text(
              timeStr,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuoteCard(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? AppColors.chatBubbleSent
        : theme.colorScheme.surfaceContainerHighest;
    final isDarkCard =
        ThemeData.estimateBrightnessForColor(bubbleColor) == Brightness.dark;
    final textColor =
        isDarkCard ? Colors.white : theme.colorScheme.onSurface;
    final fontSize = emojiFontSize(content);
    final bubbleBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(!isMe && isLastInGroup ? 8 : 20),
      bottomRight: Radius.circular(isMe && isLastInGroup ? 8 : 20),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: bubbleBorderRadius,
          ),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BubbleQuoteSection(
                  replyTo: replyTo,
                  bubbleColor: bubbleColor,
                  isGroupChat: isGroupChat,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: AlignmentDirectional.bottomEnd,
                    child: Text(
                      content.trim(),
                      textAlign: TextAlign.start,
                      style: TextStyle(fontSize: fontSize, color: textColor),
                    ),
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Align(
                      alignment: AlignmentDirectional.bottomEnd,
                      child: Text(
                        timeStr,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withAlpha(180)
                              : theme.colorScheme.onSurfaceVariant.withAlpha(
                                  180,
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isLastInGroup)
          Positioned(
            bottom: 0,
            right: isMe ? -8 : null,
            left: !isMe ? -8 : null,
            child: CustomPaint(
              painter: TailPainter(color: bubbleColor),
              size: const Size(10, 8),
            ),
          ),
      ],
    );
  }
}
