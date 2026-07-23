import 'package:flutter/material.dart';
import '../../core/debug/debug_config.dart';
import '../../core/l10n/l10n.dart';

class ReadReceiptIndicator extends StatelessWidget {
  final bool isGroupChat;
  final bool isMe;
  final bool isRead;
  final List<String> seenBy;
  final String? otherNickname;

  const ReadReceiptIndicator({
    super.key,
    required this.isGroupChat,
    required this.isMe,
    required this.isRead,
    required this.seenBy,
    this.otherNickname,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final greek = L10n.isGreek(context);

    if (isGroupChat) {
      if (seenBy.isEmpty) {
        DebugConfig.log(DebugConfig.chatBubbleDesign,
            'ReadReceiptIndicator: group hidden (seenBy empty)');
        return const SizedBox.shrink();
      }
      DebugConfig.log(DebugConfig.chatBubbleDesign,
          'ReadReceiptIndicator: group visible seenBy=${seenBy.length}');
      return Tooltip(
        message: greek
            ? 'Διαβάστηκε από ${seenBy.length} άτομα'
            : 'Seen by ${seenBy.length}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility, size: 14,
                color: theme.colorScheme.primary),
            const SizedBox(width: 2),
            Text('${seenBy.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary)),
          ],
        ),
      );
    }

    final readColor = isRead
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final iconData = isRead ? Icons.visibility : Icons.visibility_outlined;

    DebugConfig.log(DebugConfig.chatBubbleDesign,
        'ReadReceiptIndicator: 1-to-1 ${isRead ? "read" : "unread"} '
        'isRead=$isRead icon=${isRead ? "filled" : "outlined"}');

    return Tooltip(
      message: isRead
          ? (greek ? 'Διαβάστηκε' : 'Read')
          : (greek ? 'Στάλθηκε' : 'Sent'),
      child: Icon(iconData, size: 14, color: readColor),
    );
  }
}
