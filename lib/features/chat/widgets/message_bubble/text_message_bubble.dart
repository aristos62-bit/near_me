import 'package:flutter/material.dart';
import 'reply_preview.dart';
import 'tail_painter.dart';
import 'sender_header.dart';
import 'bubble_long_press_wrapper.dart';
import 'message_reactions_row.dart';
import 'read_receipt_footer.dart';

class TextMessageBubble extends StatelessWidget {
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
  final List<String> mentions;
  final Map<String, String>? participantNicknames;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TextMessageBubble({
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
    this.mentions = const [],
    this.participantNicknames,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  static const double _bubbleRadius = 20;
  static const double _tailRadius = 8;
  static const Color _sentColor = Color(0xFF075E54);
  static const Color _sentTextColor = Colors.white;

  Widget _buildRichContent(
      BuildContext context, String content, List<String> mentions, bool isMe) {
    final theme = Theme.of(context);
    final baseColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final highlightColor = isMe
        ? theme.colorScheme.onPrimary.withAlpha(200)
        : theme.colorScheme.primary;

    final spans = <TextSpan>[];
    final mentionSet = mentions.toSet();
    final nicknameToUid = participantNicknames != null
        ? {for (final e in participantNicknames!.entries) e.value: e.key}
        : <String, String>{};
    final regex = RegExp(r'@(\S+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      final nickname = match.group(1);
      final mentionedUid = nickname != null ? nicknameToUid[nickname] : null;
      final isMentioned = mentionedUid != null && mentionSet.contains(mentionedUid);
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: isMentioned ? highlightColor : baseColor,
          fontWeight: isMentioned ? FontWeight.w600 : FontWeight.normal,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return Text.rich(TextSpan(children: spans, style: TextStyle(color: baseColor)), textAlign: TextAlign.end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTail = isLastInGroup;
    final sentColor = _sentColor;
    final receivedColor = theme.colorScheme.surfaceContainerHighest;
    final bubbleColor = isMe ? sentColor : receivedColor;
    final textColor = isMe ? _sentTextColor : theme.colorScheme.onSurface;

    final bubbleBorderRadius = BorderRadius.only(
      topLeft: const Radius.circular(_bubbleRadius),
      topRight: const Radius.circular(_bubbleRadius),
      bottomLeft: Radius.circular(
          (!isMe && showTail) ? _tailRadius : _bubbleRadius),
      bottomRight: Radius.circular(
          (isMe && showTail) ? _tailRadius : _bubbleRadius),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bubbleMaxWidth = constraints.maxWidth * 0.75;
            return Column(
              mainAxisSize: MainAxisSize.min,
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
                BubbleLongPressWrapper(
                  isMe: isMe,
                  onReply: onReply,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (replyTo != null)
                        ReplyPreview(
                          replyTo: replyTo!,
                          isMe: isMe,
                          isGroupChat: isGroupChat,
                        ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: bubbleBorderRadius,
                            ),
                            child: IntrinsicWidth(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  mentions.isEmpty
                                      ? Text(content, style: TextStyle(color: textColor), textAlign: TextAlign.end)
                                      : _buildRichContent(context, content, mentions, isMe),
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Align(
                                        alignment: AlignmentDirectional.bottomEnd,
                                        child: Text(timeStr,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white.withAlpha(180)
                                                : theme.colorScheme.onSurfaceVariant.withAlpha(180),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (showTail)
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
            );
          },
        ),
      ),
    );
  }
}
