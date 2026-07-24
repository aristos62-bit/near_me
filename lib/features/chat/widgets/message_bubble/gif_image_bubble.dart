import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/read_receipt_indicator.dart';
import 'reply_preview.dart';
import 'tail_painter.dart';
import 'sender_header.dart';
import 'bubble_long_press_wrapper.dart';
import 'message_reactions_row.dart';

class GifImageBubble extends StatelessWidget {
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
  final bool isImage;
  final Map<String, dynamic> reactions;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GifImageBubble({
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
    this.isImage = false,
    this.reactions = const {},
    this.onReact,
    this.onRemove,
    this.replyTo,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  static const double _bubbleRadius = 20;
  static const double _tailRadius = 8;
  static const Color _sentColor = Color(0xFF075E54);

  static void _showImageFullScreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, _) => const CircularProgressIndicator(),
                errorWidget: (_, _, _) =>
                    const Icon(Icons.broken_image, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTail = isLastInGroup;
    final sentColor = _sentColor;
    final receivedColor = theme.colorScheme.surfaceContainerHighest;
    final bubbleColor = isMe ? sentColor : receivedColor;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bubbleMaxWidth = constraints.maxWidth * 0.75;
          return Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe &&
                  showAvatar &&
                  (senderAvatarUrl != null ||
                      (isGroupChat && senderNickname != null)))
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  BubbleLongPressWrapper(
                      isMe: isMe,
                      onReply: onReply,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      child: GestureDetector(
                        onTap: isImage ? () => _showImageFullScreen(context, content) : null,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth: bubbleMaxWidth, maxHeight: 200),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: bubbleBorderRadius,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: content,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isMe
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => SizedBox(
                          width: 200,
                          height: 200,
                          child: Icon(
                            Icons.broken_image,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
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
              MessageReactionsRow(
                chatId: chatId,
                reactions: reactions,
                currentUid: currentUid,
                messageId: messageId,
                isMe: isMe,
                onReact: onReact,
                onRemove: onRemove,
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: 2,
                  left: isMe ? 0 : 14,
                  right: isMe ? 14 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    ReadReceiptIndicator(
                      isGroupChat: isGroupChat,
                      isMe: isMe,
                      isRead: isRead,
                      seenBy: seenBy,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
