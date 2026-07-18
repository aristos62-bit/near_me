import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';

class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = L10n.relativeDateLabel(context, date);
    final dividerColor = theme.colorScheme.onSurfaceVariant.withAlpha(40);

    DebugConfig.log(
      DebugConfig.chatBubbleDesign,
      'DateSeparator: date=${date.toIso8601String()} label=$label',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(child: Divider(color: dividerColor, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            ),
          ),
          Expanded(child: Divider(color: dividerColor, height: 1)),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
