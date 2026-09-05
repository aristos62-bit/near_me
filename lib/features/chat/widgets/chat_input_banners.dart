import 'package:flutter/material.dart';

import '../../../core/debug/debug_config.dart';
import 'emoji_only_bubble.dart';
import 'message_bubble/reply_preview.dart';

/// Preview text για quoted/edited μηνύματα (emoji, media, truncated text).
/// Pure extract από το `chat_input_bar.dart` — πανομοιότυπη συμπεριφορά.
String chatMediaPreview(String type, String content, bool isEmoji, {bool greek = false}) {
  if (type == 'audio') return greek ? '🎵 Ηχογράφηση' : '🎵 Recording';
  if (type == 'gif') return '🎞️ GIF';
  if (type == 'image') return greek ? '📷 Φωτογραφία' : '📷 Photo';
  if (type == 'video') return greek ? '🎬 Βίντεο' : '🎬 Video';
  if (isEmoji) return content.trim();
  return content.length > 80 ? '${content.substring(0, 80)}...' : content;
}

/// Banner πάνω από το chat input όταν υπάρχει quote (reply).
class ChatReplyBanner extends StatelessWidget {
  final Map<String, dynamic> message;
  final Map<String, String> participantNicknames;
  final String currentUid;
  final VoidCallback onClose;

  const ChatReplyBanner({
    super.key,
    required this.message,
    required this.participantNicknames,
    required this.currentUid,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senderId = message['senderId'] as String? ?? '';
    final content = message['content'] as String? ?? '';
    final type = message['type'] as String? ?? 'text';
    final isEmoji = type == 'text' && isOnlyEmoji(content);

    final preview = chatMediaPreview(type, content, isEmoji);
    final thumbnailUrl = message['thumbnailUrl'] as String?;
    final mediaUrl = (type == 'image' || type == 'gif') && content.isNotEmpty
        ? content
        : (type == 'video' && thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : null);

    final currentSenderId = currentUid;
    final senderNickname = senderId == currentSenderId
        ? ''
        : (message['_privateReplySenderNickname'] as String? ??
        participantNicknames[senderId] ??
        senderId);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.reply, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          if (mediaUrl != null) ...[
            ReplyMediaThumbnail(imageUrl: mediaUrl),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderNickname.isNotEmpty)
                  Text(
                    senderNickname,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Text(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Banner πάνω από το chat input όταν υπάρχει μήνυμα σε επεξεργασία (edit).
class ChatEditBanner extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool greek;
  final VoidCallback onClose;

  const ChatEditBanner({
    super.key,
    required this.message,
    required this.greek,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = message['content'] as String? ?? '';
    final type = message['type'] as String? ?? 'text';
    final isEmoji = type == 'text' && isOnlyEmoji(content);

    final preview = chatMediaPreview(type, content, isEmoji, greek: greek);

    DebugConfig.log(DebugConfig.chatReply,
        'ChatInputBar: edit banner: $preview');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.edit, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greek ? 'Επεξεργασία μηνύματος' : 'Editing message',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}