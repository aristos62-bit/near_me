import 'package:flutter/material.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/l10n/l10n.dart';

class MessageActionBar {
  static Future<String?> show({
    required BuildContext context,
    required bool isOwn,
    required Offset globalPosition,
  }) {
    final greek = L10n.isGreek(context);
    final items = <PopupMenuEntry<String>>[
      if (FeatureFlags.replyToMessageEnabled)
        PopupMenuItem(
          value: 'reply',
          child: ListTile(
            leading: const Icon(Icons.reply, size: 20),
            title: Text(greek ? 'Απάντηση' : 'Reply'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (FeatureFlags.editMessageEnabled && isOwn)
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit, size: 20),
            title: Text(greek ? 'Επεξεργασία' : 'Edit'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (FeatureFlags.deleteMessageEnabled && isOwn)
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete_outline, size: 20),
            title: Text(greek ? 'Διαγραφή' : 'Delete'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
    ];
    if (items.isEmpty) return Future.value(null);
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy,
      ),
      items: items,
    );
  }
}
