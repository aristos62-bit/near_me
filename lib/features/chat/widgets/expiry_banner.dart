import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../providers/chat_provider.dart';
import '../utils/message_expiry.dart';

/// Banner αυτόματης διαγραφής μηνυμάτων (P3.2).
///
/// Εξαχθείσα από το `chat_screen.dart` (όριο 500 γραμμών) — ίδια συμπεριφορά:
/// παρακολουθεί το `messageExpiry` του chat (group ή 1-1) και δείχνει
/// ειδοποίηση 5sec σε κάθε αλλαγή. Leaf widget, υπάρχον `select` pattern,
/// κανένας νέος listener.
class ExpiryBanner extends ConsumerStatefulWidget {
  final String chatId;
  const ExpiryBanner({super.key, required this.chatId});

  @override
  ConsumerState<ExpiryBanner> createState() => _ExpiryBannerState();
}

class _ExpiryBannerState extends ConsumerState<ExpiryBanner> {
  bool _visible = false;
  String _lastExpiry = 'off';
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _onExpiryChanged(String expiry) {
    _dismissTimer?.cancel();
    if (expiry != 'off') {
      setState(() => _visible = true);
      _dismissTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _visible = false);
      });
    } else {
      setState(() => _visible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiry = ref.watch(chatDocProvider(widget.chatId).select(
      (a) => (a.asData?.value?.data() as Map<String, dynamic>?)?['messageExpiry'] as String? ?? 'off',
    ));

    if (expiry != _lastExpiry) {
      _lastExpiry = expiry;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onExpiryChanged(expiry);
      });
    }

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: _visible ? _buildBanner(expiry) : const SizedBox(height: 0),
    );
  }

  Widget _buildBanner(String expiry) {
    final greek = L10n.isGreek(context);
    final display = MessageExpiry.display(expiry, greek: greek);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  greek
                      ? 'Τα μηνύματα διαγράφονται μετά από $display'
                      : 'Messages auto-delete after $display',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
