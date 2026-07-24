import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Κοινό header (avatar + nickname) που εμφανίζεται πάνω από τα bubbles
/// σε group chats. Η ΟΡΑΤΟΤΗΤΑ αποφασίζεται από τον caller (κάθε bubble
/// έχει τη δική του συνθήκη εμφάνισης) — αυτό το widget μόνο σχεδιάζει.
class SenderHeader extends StatelessWidget {
  final String? senderAvatarUrl;
  final String? senderNickname;
  final bool isGroupChat;

  const SenderHeader({
    super.key,
    required this.senderAvatarUrl,
    required this.senderNickname,
    required this.isGroupChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: senderAvatarUrl != null
                ? CachedNetworkImageProvider(senderAvatarUrl!)
                : null,
            child: senderAvatarUrl == null && senderNickname != null
                ? Text(senderNickname![0], style: const TextStyle(fontSize: 18))
                : null,
          ),
          if (isGroupChat && senderNickname != null) ...[
            const SizedBox(width: 4),
            Text(senderNickname!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}