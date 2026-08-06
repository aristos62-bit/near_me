import 'package:flutter/material.dart';
import '../../../core/l10n/l10n.dart';

/// Leaf widget — modal sheet με preview του εισερχόμενου shared content.
/// Επιστρέφει true αν ο χρήστης θέλει να προωθηθεί σε συνομιλία.
/// Δεν κάνει κανένα watch → μηδέν rebuilds.
Future<bool?> showIncomingShareSheet(
  BuildContext context, {
  required String type,
  required String content,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    builder: (ctx) {
      final greek = L10n.isGreek(ctx);
      final isUrl = type == 'url' ||
          content.trimLeft().startsWith(RegExp(r'^https?://'));
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isUrl ? Icons.link : Icons.forward_to_inbox_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      greek ? 'Εισερχόμενο περιεχόμενο' : 'Incoming content',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(content, style: Theme.of(ctx).textTheme.bodyMedium),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text(greek ? 'Προώθηση σε συνομιλία' : 'Forward to a chat'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
