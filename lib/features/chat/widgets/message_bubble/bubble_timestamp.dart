import 'package:flutter/material.dart';

/// Κοινό timestamp row (lock + χρόνος) των message bubbles — πανομοιότυπο με το
/// block που υπήρχε σε video_message_bubble.dart και audio_message_bubble.dart.
/// Χρήση `Theme.of(context)` εσωτερικά (ίδιο theme σε όλο το subtree).
class BubbleTimestamp extends StatelessWidget {
  final String timeStr;
  final bool isMe;

  const BubbleTimestamp({
    super.key,
    required this.timeStr,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: isMe ? 0 : 14,
        right: isMe ? 14 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
