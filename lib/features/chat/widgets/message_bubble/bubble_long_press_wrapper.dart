import 'package:flutter/material.dart';
import '../message_action_bar.dart';

/// Κοινό wrapper που ανοίγει το [MessageActionBar] σε long-press
/// και προωθεί την επιλογή του χρήστη (reply/edit/delete) στα
/// αντίστοιχα callbacks. Χρησιμοποιείται από όλα τα τύπου bubble
/// (text, gif/image, emoji-only) για να αποφευχθεί επανάληψη κώδικα.
class BubbleLongPressWrapper extends StatelessWidget {
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget child;

  const BubbleLongPressWrapper({
    super.key,
    required this.isMe,
    required this.child,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) async {
        final result = await MessageActionBar.show(
          context: context,
          isOwn: isMe,
          globalPosition: details.globalPosition,
        );
        if (result == 'reply') onReply?.call();
        if (result == 'edit') onEdit?.call();
        if (result == 'delete') onDelete?.call();
      },
      child: child,
    );
  }
}