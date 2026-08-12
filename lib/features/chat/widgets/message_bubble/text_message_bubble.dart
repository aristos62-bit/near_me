import 'package:flutter/material.dart';
import 'reply_preview.dart';
import 'tail_painter.dart';
import 'sender_header.dart';
import 'bubble_long_press_wrapper.dart';
import '../message_reactions.dart';

import 'read_receipt_footer.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter/gestures.dart';

class TextMessageBubble extends StatelessWidget {
  final String content;
  final double bubbleMaxWidth;
  final String timeStr;
  final bool isMe;
  final bool isGroupChat;
  final bool isSenderBlockedByMe;
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
  final VoidCallback? onReplyPrivately;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;
  final VoidCallback? onEmail;
  final VoidCallback? onShare;
  final void Function(String url)? onLinkTap;

  const TextMessageBubble({
    super.key,
    required this.content,
    required this.bubbleMaxWidth,
    required this.timeStr,
    required this.isMe,
    this.isGroupChat = false,
    this.isSenderBlockedByMe = false,
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
    this.onReplyPrivately,
    this.onEdit,
    this.onDelete,
    this.onInfo,
    this.onEmail,
    this.onShare,
    this.onLinkTap,
  });

  static const double _bubbleRadius = 20;
  static const double _tailRadius = 8;
  static const Color _sentColor = AppColors.chatBubbleSent;
  static const Color _sentTextColor = Colors.white;

  static final RegExp _linkDetector = RegExp(r'https?://|www\.');

  Widget _buildRichContent(
    BuildContext context,
    String content,
    List<String> mentions,
    bool isMe,
  ) {
    final theme = Theme.of(context);
    final baseColor = isMe ? _sentTextColor : theme.colorScheme.onSurface;
    final highlightColor = isMe
        ? theme.colorScheme.onPrimary.withAlpha(200)
        : theme.colorScheme.primary;
    final linkColor = isMe ? _sentTextColor : theme.colorScheme.primary;

    final spans = <InlineSpan>[];
    final mentionSet = mentions.toSet();
    final nicknameToUid = participantNicknames != null
        ? {for (final e in participantNicknames!.entries) e.value: e.key}
        : <String, String>{};
    final regex = RegExp(r'(@\S+)|((?:https?://|www\.)\S+)');
    final trailingPunct = RegExp(r'''[.,!?;:)\]"']+$''');
    int lastEnd = 0;

    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      final mentionText = match.group(1);
      if (mentionText != null) {
        final nickname = mentionText.substring(1);
        final mentionedUid = nicknameToUid[nickname];
        final isMentioned =
            mentionedUid != null && mentionSet.contains(mentionedUid);
        spans.add(
          TextSpan(
            text: mentionText,
            style: TextStyle(
              color: isMentioned ? highlightColor : baseColor,
              fontWeight: isMentioned ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
        lastEnd = match.end;
        continue;
      }

      final rawUrl = match.group(2)!;
      var urlText = rawUrl;
      var urlEnd = match.end;
      final trailMatch = trailingPunct.firstMatch(rawUrl);
      if (trailMatch != null) {
        urlText = rawUrl.substring(0, trailMatch.start);
        urlEnd -= (rawUrl.length - urlText.length);
      }
      final linkTarget = urlText;
      spans.add(
        TextSpan(
          text: urlText,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onLinkTap?.call(linkTarget),
        ),
      );
      lastEnd = urlEnd;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        children: spans,
        style: TextStyle(color: baseColor),
      ),
      textAlign: TextAlign.start,
    );
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
        (!isMe && showTail) ? _tailRadius : _bubbleRadius,
      ),
      bottomRight: Radius.circular(
        (isMe && showTail) ? _tailRadius : _bubbleRadius,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              isGroupChat: isGroupChat,
              isSenderBlockedByMe: isSenderBlockedByMe,
              isMe: isMe,
              onReply: onReply,
              onReplyPrivately: onReplyPrivately,
              onEdit: onEdit,
              onDelete: onDelete,
              onInfo: onInfo,
              onEmail: onEmail,
              onShare: onShare,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: bubbleBorderRadius,
                    ),
                    child: IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (replyTo != null)
                            BubbleQuoteSection(
                              replyTo: replyTo,
                              bubbleColor: bubbleColor,
                              isGroupChat: isGroupChat,
                            ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              (mentions.isEmpty &&
                                      !_linkDetector.hasMatch(content))
                                  ? Text(
                                      content,
                                      style: TextStyle(color: textColor),
                                      textAlign: TextAlign.start,
                                    )
                                  : _buildRichContent(
                                      context,
                                      content,
                                      mentions,
                                      isMe,
                                    ),
                              if (timeStr.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Align(
                                    alignment: AlignmentDirectional.bottomEnd,
                                    child: Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white.withAlpha(180)
                                            : theme.colorScheme.onSurfaceVariant
                                                  .withAlpha(180),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
      ),
    );
  }
}
