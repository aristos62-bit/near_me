import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';

class SystemMessageBubble extends StatelessWidget {
  final String content;
  final String? contentEn;
  final String timeStr;
  final String? action;
  final bool isRequester;
  final String? chatId;
  final Future<void> Function(String chatId)? onApproveDelete;
  final Future<void> Function(String chatId)? onRejectDelete;
  final Future<void> Function(String chatId)? onDeleteForMe;
  final Future<void> Function(String chatId)? onKeepChat;

  const SystemMessageBubble({
    super.key,
    required this.content,
    this.contentEn,
    required this.timeStr,
    this.action,
    this.isRequester = false,
    this.chatId,
    this.onApproveDelete,
    this.onRejectDelete,
    this.onDeleteForMe,
    this.onKeepChat,
  });

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final displayContent = isGreek ? content : (contentEn ?? content);
    final showActions = chatId != null && !isRequester && (
        action == 'delete_request' || action == 'delete_rejected'
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Center(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(120),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                displayContent,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ),
          if (showActions && action == 'delete_request')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    onPressed: () => onApproveDelete?.call(chatId!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Ναι' : 'Yes'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => onRejectDelete?.call(chatId!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Όχι' : 'No'),
                  ),
                ],
              ),
            ),
          if (showActions && action == 'delete_rejected')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonal(
                    onPressed: () => onDeleteForMe?.call(chatId!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Ναι, μόνο για εμένα' : 'Yes, for me'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async => onKeepChat?.call(chatId!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    child: Text(isGreek ? 'Όχι, παράμεινε' : 'No, keep it'),
                  ),
                ],
              ),
            ),
          if (timeStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(timeStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
