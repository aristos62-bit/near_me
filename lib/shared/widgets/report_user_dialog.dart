import 'package:flutter/material.dart';
import '../../core/l10n/l10n.dart';

Future<String?> showReportUserDialog(BuildContext context, bool isGreek) async {
  final reasons = L10n.reportReasons();
  String? selectedReason;

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isGreek ? 'Αναφορά Χρήστη' : 'Report User',
          style: theme.textTheme.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGreek
                  ? 'Γιατί αναφέρεις αυτόν τον χρήστη;'
                  : 'Why are you reporting this user?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: selectedReason,
              onChanged: (v) {
                selectedReason = v;
                Navigator.of(ctx).pop(v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: reasons.map((r) => RadioListTile<String>(
                  title: Text(L10n.reportReasonLabel(r, isGreek: isGreek)),
                  value: r,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isGreek ? 'Ακύρωση' : 'Cancel'),
          ),
        ],
      );
    },
  );
}
