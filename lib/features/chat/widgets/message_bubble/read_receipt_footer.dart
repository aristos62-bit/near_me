import 'package:flutter/material.dart';
import '../../../../shared/widgets/read_receipt_indicator.dart';

/// Footer με το [ReadReceiptIndicator], εμφανίζεται μόνο για δικά μας
/// μηνύματα (isMe). Κοινή χρήση σε text & emoji-only bubbles
/// (το gif/image bubble έχει διαφορετικό layout — δεν το χρησιμοποιεί).
class ReadReceiptFooter extends StatelessWidget {
  final bool isMe;
  final bool isGroupChat;
  final bool isRead;
  final List<String> seenBy;

  const ReadReceiptFooter({
    super.key,
    required this.isMe,
    required this.isGroupChat,
    required this.isRead,
    required this.seenBy,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 14),
      child: ReadReceiptIndicator(
        isGroupChat: isGroupChat,
        isMe: isMe,
        isRead: isRead,
        seenBy: seenBy,
      ),
    );
  }
}