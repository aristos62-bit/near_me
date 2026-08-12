import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/feature_flags.dart';

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

    if (grouped.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: isMe ? 0 : 14,
        right: isMe ? 14 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
    );
  }

  void _toggle(BuildContext context, String emoji) {
    final currentEmoji = reactions[currentUid] as String?;
    final isRemove = currentEmoji == emoji;
    if (isRemove) {
      onRemove?.call(messageId);
    } else {
      onReact?.call(messageId, emoji);
    }
  }
}

/// Εικονίδιο αντίδρασης δίπλα στο bubble (αριστερά στα δικά μας
/// μηνύματα, δεξιά στου άλλου), κάθετα στο μέσο της κάρτας.
///
/// - Χωρίς δική μου αντίδραση: ημιδιαφανές [Icons.add_reaction_outlined],
///   long-press → [showReactionPicker].
/// - Με δική μου αντίδραση: δείχνει το emoji μου με border σε primary,
///   tap → αφαίρεση, long-press → [showReactionPicker].
/// - Δίπλα: σύνολα reactions (emoji + πλήθος όταν >1), χωρίς τίποτα κάτω
///   από το μήνυμα.
/// Δεν κινεί rebuild cascade: Stateless χωρίς MediaQuery/LayoutBuilder/L10n
/// — μόνο Theme.of (rebuild storm μαθήματα Sessions 196/200/222/224).
class ReactionTriggerIcon extends StatelessWidget {
  final String? chatId;
  final String messageId;
  final Map<String, dynamic> reactions;
  final String currentUid;
  final bool isMe;
  final Future<void> Function(String messageId, String emoji)? onReact;
  final Future<void> Function(String messageId)? onRemove;

  const ReactionTriggerIcon({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.reactions,
    required this.currentUid,
    required this.isMe,
    this.onReact,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (chatId == null || !FeatureFlags.messageReactionsEnabled) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final myEmoji = reactions[currentUid] as String?;

    final Map<String, int> grouped = {};
    for (final e in reactions.values) {
      final emoji = e as String? ?? '';
      if (emoji.isNotEmpty) grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }

    return GestureDetector(
      onTap: myEmoji == null ? null : () => onRemove?.call(messageId),
      onLongPress: () => showReactionPicker(
        context: context,
        messageId: messageId,
        currentEmoji: myEmoji,
        onReact: onReact,
        onRemove: onRemove,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: myEmoji == null
                      ? theme.colorScheme.onSurfaceVariant.withAlpha(140)
                      : theme.colorScheme.primary.withAlpha(180),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: myEmoji == null
                  ? Icon(
                      Icons.add_reaction_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                    )
                  : SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: Text(
                          myEmoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
            ),
            if (!isMe && grouped.isNotEmpty) ...[
              const SizedBox(width: 4),
              Wrap(
                spacing: 3,
                runSpacing: 2,
                children: [
                  for (final entry in grouped.entries)
                    _ReactionCountBadge(
                      emoji: entry.key,
                      count: entry.value,
                      theme: theme,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReactionCountBadge extends StatelessWidget {
  final String emoji;
  final int count;
  final ThemeData theme;

  const _ReactionCountBadge({
    required this.emoji,
    required this.count,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 1 ? '$emoji $count' : emoji,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

Future<void> showReactionPicker({
  required BuildContext context,
  required String messageId,
  String? currentEmoji,
  required Future<void> Function(String messageId, String emoji)? onReact,
  Future<void> Function(String messageId)? onRemove,
}) {
  return showModalBottomSheet(
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
                  _reactionEmojiButton(
                      context, messageId, currentEmoji, onReact, onRemove, '😂'),
                  _reactionEmojiButton(
                      context, messageId, currentEmoji, onReact, onRemove, '😮'),
                  _reactionEmojiButton(
                      context, messageId, currentEmoji, onReact, onRemove, '😢'),
                  _reactionEmojiButton(
                      context, messageId, currentEmoji, onReact, onRemove, '😠'),
                  _reactionEmojiButton(
                      context, messageId, currentEmoji, onReact, onRemove, '❤️'),
                  _reactionEmojiButton(
                      context, messageId, currentEmoji, onReact, onRemove, '👏'),
                  InkWell(
                    onTap: () =>
                        _reactionFullPicker(context, messageId, currentEmoji, onReact, onRemove),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        Icons.add,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

Widget _reactionEmojiButton(
  BuildContext context,
  String messageId,
  String? currentEmoji,
  Future<void> Function(String messageId, String emoji)? onReact,
  Future<void> Function(String messageId)? onRemove,
  String emoji,
) {
  return InkWell(
    onTap: () {
      Navigator.pop(context);
      if (currentEmoji == emoji) {
        onRemove?.call(messageId);
      } else {
        onReact?.call(messageId, emoji);
      }
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

Future<void> _reactionFullPicker(
  BuildContext context,
  String messageId,
  String? currentEmoji,
  Future<void> Function(String messageId, String emoji)? onReact,
  Future<void> Function(String messageId)? onRemove,
) {
  Navigator.pop(context);
  return showModalBottomSheet(
    context: context,
    builder: (_) => SizedBox(
      height: 300,
      child: EmojiPicker(
        onEmojiSelected: (_, emoji) {
          Navigator.pop(context);
          if (currentEmoji == emoji.emoji) {
            onRemove?.call(messageId);
          } else {
            onReact?.call(messageId, emoji.emoji);
          }
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
