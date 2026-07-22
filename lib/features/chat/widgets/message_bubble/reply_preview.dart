import 'package:flutter/material.dart';

class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final bool isMe;
  final bool isGroupChat;

  const ReplyPreview({
    super.key,
    required this.replyTo,
    required this.isMe,
    this.isGroupChat = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senderNickname = replyTo['senderNickname'] as String?;
    final contentPreview = replyTo['contentPreview'] as String? ?? '';
    final preview = isGroupChat && senderNickname != null
        ? '@$senderNickname: $contentPreview'
        : contentPreview;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(180),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        preview,
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
