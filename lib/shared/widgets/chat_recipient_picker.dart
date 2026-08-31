import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n.dart';
import '../../../data/local/database.dart';
import '../utils/avatar_blur.dart';

/// Shared recipient picker: bottom sheet με τα υπάρχοντα chats για επιλογή
/// παραλήπτη. SPoT — χρησιμοποιείται από το Forward (ChatMessagesList) και
/// από το IncomingShareSheet. Επιστρέφει το chatId ή null (ακύρωση).
///
/// ΔΕΝ κάνει watch — δέχεται snapshot της λίστας chats → μηδέν rebuilds.
/// Λαμβάνει τη λίστα ως όρισμα ώστε ο καλών να ελέγχει το empty-case.
///
/// [blurEnabled]/[blurSigma] προέρχονται από τον καλούντα (από appSettingsProvider) —
/// το widget αυτό παραμένει χωρίς watch.
Future<String?> showChatRecipientPicker(
  BuildContext context,
  List<ChatCacheTableData> chats, {
  required bool blurEnabled,
  double blurSigma = 12.0,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(L10n.isGreek(ctx) ? 'Προώθηση σε' : 'Forward to',
              style: Theme.of(ctx).textTheme.titleMedium),
        ),
        ...chats.map((chat) {
          final isGroup = chat.isGroupChat;
          final title = isGroup ? (chat.groupName ?? '') : (chat.otherNickname ?? '');
          final avatarUrl = isGroup ? chat.groupAvatarUrl : chat.otherAvatarUrl;
          final avatar = CircleAvatar(
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Icon(isGroup ? Icons.group : Icons.person)
                : null,
          );
          return ListTile(
            leading: isGroup
                ? wrapAvatarBlur(
                    blurOn: blurEnabled,
                    racyLevel: chat.groupAvatarRacyLevel,
                    sigma: blurSigma,
                    child: avatar,
                  )
                : avatar,
            title: Text(title),
            onTap: () => Navigator.of(ctx).pop(chat.chatId),
          );
        }),
      ],
    ),
  );
}
