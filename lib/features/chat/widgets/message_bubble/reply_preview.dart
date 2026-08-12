import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

String _replyPreviewText(Map<String, dynamic> replyTo, bool isGroupChat) {
  final senderNickname = replyTo['senderNickname'] as String?;
  final contentPreview = replyTo['contentPreview'] as String? ?? '';
  final mediaUrl = ReplyMediaThumbnail.urlFor(replyTo);
  final isMedia = mediaUrl != null;

  return isMedia
      ? (isGroupChat && senderNickname != null ? '@$senderNickname' : '')
      : (isGroupChat && senderNickname != null
            ? '@$senderNickname: $contentPreview'
            : contentPreview);
}

/// Ενσωματωμένο quote στην κορυφή του bubble (WhatsApp style).
/// Flattened: χωρίς δικό του background/radius/margin — τα δίνει το bubble.
/// Το χρώμα accent/text/divider υπολογίζεται contrast-aware σε σχέση
/// με το χρώμα του bubble (για sent bubbles π.χ. #075E54 → άσπρο accent).
class BubbleQuoteSection extends StatelessWidget {
  final Map<String, dynamic>? replyTo;
  final Color bubbleColor;
  final bool isGroupChat;
  final GlobalKey? dividerKey;

  const BubbleQuoteSection({
    super.key,
    required this.replyTo,
    required this.bubbleColor,
    this.isGroupChat = false,
    this.dividerKey,
  });

  @override
  Widget build(BuildContext context) {
    final reply = replyTo;
    if (reply == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark =
        ThemeData.estimateBrightnessForColor(bubbleColor) == Brightness.dark;
    final accentColor =
        isDark ? Colors.white.withAlpha(180) : theme.colorScheme.primary;
    final textColor =
        isDark ? Colors.white.withAlpha(230) : theme.colorScheme.onSurfaceVariant;
    final dividerColor =
        isDark ? Colors.white.withAlpha(60) : theme.colorScheme.onSurfaceVariant.withAlpha(50);
    final thumbPlaceholderColor =
        isDark ? Colors.white.withAlpha(36) : theme.colorScheme.surfaceContainerHighest.withAlpha(120);

    final mediaUrl = ReplyMediaThumbnail.urlFor(reply);
    final textWidget = Text(
      _replyPreviewText(reply, isGroupChat),
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
        color: textColor,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
            ),
          ),
          child: mediaUrl != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReplyMediaThumbnail(
                      imageUrl: mediaUrl,
                      surfaceColor: thumbPlaceholderColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: textWidget),
                  ],
                )
              : textWidget,
        ),
        SizedBox(
          key: dividerKey,
          height: 12,
          child: Center(
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: dividerColor),
            ),
          ),
        ),
      ],
    );
  }
}

class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  final bool isMe;
  final bool isGroupChat;
  final double? maxWidth;

  const ReplyPreview({
    super.key,
    required this.replyTo,
    required this.isMe,
    this.isGroupChat = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaUrl = ReplyMediaThumbnail.urlFor(replyTo);
    final isMedia = mediaUrl != null;

    final textWidget = Text(
      _replyPreviewText(replyTo, isGroupChat),
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(180),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: isMedia
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReplyMediaThumbnail(imageUrl: mediaUrl),
                  const SizedBox(width: 8),
                  Flexible(child: textWidget),
                ],
              )
            : textWidget,
      ),
    );
  }
}

class ReplyMediaThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;
  final Color? surfaceColor;

  const ReplyMediaThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 44,
    this.surfaceColor,
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
    final placeholderColor =
        surfaceColor ?? theme.colorScheme.surfaceContainerHighest.withAlpha(120);
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
          color: placeholderColor,
        ),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: placeholderColor,
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
