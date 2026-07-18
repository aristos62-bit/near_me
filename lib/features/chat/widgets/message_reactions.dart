import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';

class MessageReactions extends StatelessWidget {
  final Map<String, dynamic> reactions;
  final String currentUid;
  final String chatId;
  final String messageId;
  final bool isMe;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;

  const MessageReactions({
    super.key,
    required this.reactions,
    required this.currentUid,
    required this.chatId,
    required this.messageId,
    required this.isMe,
    this.onReact,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final userEmoji = reactions[currentUid] as String?;

    final Map<String, List<String>> grouped = {};
    for (final entry in reactions.entries) {
      final emoji = entry.value as String? ?? '';
      grouped.putIfAbsent(emoji, () => []).add(entry.key);
    }

    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: isMe ? 0 : 14,
        right: isMe ? 14 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (grouped.isNotEmpty)
            Flexible(
              child: Wrap(
                spacing: 3,
                runSpacing: 2,
                children: grouped.entries.map((e) {
                  final count = e.value.length;
                  final isUser = userEmoji == e.key;
                  return _ReactionChip(
                    emoji: e.key,
                    count: count,
                    isHighlighted: isUser,
                    theme: theme,
                    onTap: () => _toggle(context, e.key),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(width: 4),
          _ReactionTrigger(
            onLongPress: () => _showPicker(context),
          ),
        ],
      ),
    );
  }

  void _toggle(BuildContext context, String emoji) {
    final currentEmoji = reactions[currentUid] as String?;
    final isRemove = currentEmoji == emoji;
    DebugConfig.log(DebugConfig.chatReactions,
        'MessageReactions: toggle msg=$messageId emoji=$emoji isRemove=$isRemove');
    if (isRemove) {
      onRemove?.call(messageId);
    } else {
      onReact?.call(messageId, emoji);
    }
  }

  void _showPicker(BuildContext context) {
    DebugConfig.log(DebugConfig.chatReactions,
        'MessageReactions: picker shown msg=$messageId');
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _emojiButton(context, '😂'),
                    _emojiButton(context, '😮'),
                    _emojiButton(context, '😢'),
                    _emojiButton(context, '😠'),
                    _emojiButton(context, '❤️'),
                    _emojiButton(context, '👏'),
                    InkWell(
                      onTap: () => _showEmojiPicker(context),
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Icon(Icons.add, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emojiButton(BuildContext context, String emoji) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onReact?.call(messageId, emoji);
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF0F0F0),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 300,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) {
            Navigator.pop(context);
            onReact?.call(messageId, emoji.emoji);
          },
          config: const Config(
            categoryViewConfig: CategoryViewConfig(
              initCategory: Category.SMILEYS,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isHighlighted;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isHighlighted,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: isHighlighted
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (count > 1) ...[
              const SizedBox(width: 2),
              Text('$count',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReactionTrigger extends StatelessWidget {
  final VoidCallback onLongPress;

  const _ReactionTrigger({required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Icon(
        Icons.add_reaction_outlined,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
      ),
    );
  }
}
