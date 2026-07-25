import 'package:flutter/material.dart';
import '../message_action_bar.dart';

/// Κοινό wrapper που ανοίγει το [MessageActionBar] σε long-press
/// και προωθεί την επιλογή του χρήστη (reply/edit/delete/info/email/share)
/// στα αντίστοιχα callbacks. Χρησιμοποιείται από όλα τα τύπου bubble
/// (text, gif/image, emoji-only, audio, video) για να αποφευχθεί
/// επανάληψη κώδικα.
///
/// Το menu ανοίγει πάντα σε σταθερή θέση σχετικά με το bubble
/// (όχι στο ακριβές σημείο του tap): κέντρο-δεξιά για ξένα μηνύματα,
/// κέντρο-αριστερά για δικά μας.
class BubbleLongPressWrapper extends StatelessWidget {
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;
  final VoidCallback? onEmail;
  final VoidCallback? onShare;
  final Widget child;
  final bool canEdit;

  const BubbleLongPressWrapper({
    super.key,
    required this.isMe,
    required this.child,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onInfo,
    this.onEmail,
    this.onShare,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) async {
        final box = context.findRenderObject() as RenderBox?;
        Offset anchor = details.globalPosition;
        if (box != null && box.attached) {
          final topLeft = box.localToGlobal(Offset.zero);
          anchor = Offset(
            isMe ? topLeft.dx : topLeft.dx + box.size.width,
            topLeft.dy + box.size.height / 2,
          );
        }
        final result = await MessageActionBar.show(
          context: context,
          isOwn: isMe,
          globalPosition: anchor,
          showEdit: canEdit,
        );
        if (result == 'reply') onReply?.call();
        if (result == 'edit') onEdit?.call();
        if (result == 'delete') onDelete?.call();
        if (result == 'info') onInfo?.call();
        if (result == 'email') onEmail?.call();
        if (result == 'share') onShare?.call();
      },
      child: child,
    );
  }
}