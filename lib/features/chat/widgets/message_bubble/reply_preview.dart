import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/debug/debug_config.dart';

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

    final mediaUrl = ReplyMediaThumbnail.urlFor(replyTo);
    final isMedia = mediaUrl != null;
    DebugConfig.log(DebugConfig.chatReply,
        'ReplyPreview: thumbnail=${isMedia ? "yes" : "no"}');

    final textWidget = Text(
      preview,
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

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
      child: isMedia
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReplyMediaThumbnail(imageUrl: mediaUrl),
                const SizedBox(width: 8),
                Expanded(child: textWidget),
              ],
            )
          : textWidget,
    );
  }
}

class ReplyMediaThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;

  const ReplyMediaThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 44,
  });

  /// Επιστρέφει το URL εικόνας/thumbnail του quoted μηνύματος (SPoT).
  /// image/gif → content (Storage/GIPHY URL) · video → thumbnailUrl.
  static String? urlFor(Map<String, dynamic> replyTo) {
    final type = replyTo['type'] as String? ?? 'text';
    final mediaUrl = type == 'video'
        ? (replyTo['thumbnailUrl'] as String?)
        : (replyTo['content'] as String?);
    if (type != 'image' && type != 'gif' && type != 'video') return null;
    if (mediaUrl == null || mediaUrl.isEmpty) return null;
    return mediaUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        ),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
          child: Icon(
            Icons.broken_image,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
