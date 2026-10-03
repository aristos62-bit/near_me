import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/connectivity_guard.dart';
import '../../../core/utils/error_messages.dart';
import '../providers/chat_provider.dart';

/// Φύλλο επιλογής αυτόματης διαγραφής μηνυμάτων για 1-1 chats (P3.2 extension).
///
/// Reuse του group pattern (`group_settings_screen.dart`): ίδιες 7 τιμές,
/// ίδια bilingual labels, ίδια error codes, `ConnectivityGuard.ensure`,
/// `mounted` guards. Η αποθήκευση γίνεται με κουμπί (όχι on-change),
/// κατάλληλο για dialog. Δεν αγγίζει group ροές.
Future<void> showOneToOneExpirySheet(
  BuildContext context,
  WidgetRef ref,
  String chatId,
  String currentValue,
) async {
  if (!FeatureFlags.messageExpiryEnabled) return;
  DebugConfig.log(DebugConfig.uiInteraction,
      'OneToOneExpirySheet: open chat=$chatId current=$currentValue');

  final actions = ref.read(chatActionsProvider.notifier);
  final greek = L10n.isGreek(context);

  final saved = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ExpiryDialog(initialValue: currentValue),
  );
  if (saved == null || saved == currentValue) return;
  if (!context.mounted) return;
  if (!await ConnectivityGuard.ensure(context)) return;

  DebugConfig.log(DebugConfig.chatMessageExpiry,
      'OneToOneExpirySheet: save chat=$chatId value=$saved');
  final ok = await actions.updateOneToOneMessageExpiry(chatId, saved);
  if (!context.mounted) return;
  if (ok) {
    AppMessenger.showSuccess(
        context, ErrorMessages.get('chat/message-expiry-updated', greek));
  } else {
    final st = ref.read(chatActionsProvider);
    AppMessenger.showError(context, ErrorMessages.get(
        st.errorMessage ?? 'chat/message-expiry-update-failed', greek));
  }
}

class _ExpiryDialog extends StatefulWidget {
  final String initialValue;
  const _ExpiryDialog({required this.initialValue});

  @override
  State<_ExpiryDialog> createState() => _ExpiryDialogState();
}

class _ExpiryDialogState extends State<_ExpiryDialog> {
  late String _selected = widget.initialValue;

  DropdownMenuItem<String> _item(String value, String label) {
    return DropdownMenuItem(value: value, child: Text(label));
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(greek ? 'Αυτόματη διαγραφή' : 'Auto-delete'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greek
                ? 'Τα νέα μηνύματα θα διαγράφονται αυτόματα μετά από:'
                : 'New messages will auto-delete after:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(widget.initialValue),
            initialValue: _selected,
            decoration: InputDecoration(
              labelText: greek ? 'Διαγραφή μετά από' : 'Delete after',
              isDense: true,
              border: InputBorder.none,
            ),
            items: [
              _item('off', greek ? 'Απενεργοποιημένο' : 'Off'),
              _item('1min', greek ? '1 λεπτό' : '1 minute'),
              _item('5min', greek ? '5 λεπτά' : '5 minutes'),
              _item('30min', greek ? '30 λεπτά' : '30 minutes'),
              _item('6h', greek ? '6 ώρες' : '6 hours'),
              _item('12h', greek ? '12 ώρες' : '12 hours'),
              _item('24h', greek ? '24 ώρες' : '24 hours'),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selected = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(greek ? 'Ακύρωση' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(greek ? 'Αποθήκευση' : 'Save'),
        ),
      ],
    );
  }
}
