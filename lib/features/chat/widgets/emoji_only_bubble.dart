import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';

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
  if (effective <= 1) return 64;
  if (effective <= 3) return 48;
  if (effective <= 6) return 36;
  return 28;
}

class EmojiOnlyBubble extends StatelessWidget {
  final String content;
  final String timeStr;
  final bool isMe;
  final bool isGroupChat;
  final String? senderNickname;
  final List<String> seenBy;
  final bool isRead;

  const EmojiOnlyBubble({
    super.key,
    required this.content,
    required this.timeStr,
    required this.isMe,
    this.isGroupChat = false,
    this.senderNickname,
    this.seenBy = const [],
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize = emojiFontSize(content);
    DebugConfig.log(DebugConfig.uiInteraction,
        'EmojiOnlyBubble: "${content.trim()}" fontSize=$fontSize');
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * 0.75;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isGroupChat && !isMe && senderNickname != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 2),
                  child: Text(
                    senderNickname!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Text(
                  content.trim(),
                  style: TextStyle(
                    fontSize: fontSize,
                    color: isMe
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                    top: 2,
                    left: isMe ? 0 : 14,
                    right: isMe ? 14 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeStr, style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (isGroupChat && isMe && seenBy.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.visibility, size: 14,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 2),
                      Text('${seenBy.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary)),
                    ],
                    if (!isGroupChat && isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
