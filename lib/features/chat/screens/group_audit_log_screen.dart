import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../providers/chat_provider.dart';

class AuditLogEntry {
  final String id;
  final String chatId;
  final String action;
  final String actor;
  final String? actorName;
  final String? targetUid;
  final String? details;
  final DateTime? timestamp;

  const AuditLogEntry({
    required this.id,
    required this.chatId,
    required this.action,
    required this.actor,
    this.actorName,
    this.targetUid,
    this.details,
    this.timestamp,
  });

  factory AuditLogEntry.fromDoc(String chatId, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['timestamp'];
    final rawDetails = data['details'];
    final detailsStr = rawDetails is Map
        ? rawDetails.entries.map((e) => '${e.key}: ${e.value}').join(', ')
        : rawDetails as String?;
    return AuditLogEntry(
      id: doc.id,
      chatId: chatId,
      action: data['action'] as String? ?? 'unknown',
      actor: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String?,
      targetUid: data['targetUid'] as String?,
      details: detailsStr,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

final auditLogStreamProvider = StreamProvider.autoDispose.family<List<AuditLogEntry>, String>((ref, chatId) {
  DebugConfig.log(DebugConfig.providerCreate, 'auditLogStreamProvider created for chat: $chatId');
  ref.onDispose(() => DebugConfig.log(DebugConfig.providerDispose, 'auditLogStreamProvider disposed for chat: $chatId'));
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('audit_log')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => AuditLogEntry.fromDoc(chatId, doc)).toList());
});

String _actionIcon(String action) {
  switch (action) {
    case 'group_created': return 'add_circle';
    case 'member_added': return 'person_add';
    case 'member_removed': return 'person_remove';
    case 'member_left': return 'exit_to_app';
    case 'group_name_changed': return 'edit';
    case 'group_avatar_changed': return 'photo_camera';
    case 'group_avatar_removed': return 'photo_off';
    case 'max_participants_changed': return 'group';
    case 'role_changed': return 'manage_accounts';
    case 'permission_override_added': return 'security';
    case 'permission_override_removed': return 'security_off';
    case 'invite_created': return 'link';
    case 'invite_revoked': return 'link_off';
    case 'settings_updated': return 'settings';
    default: return 'info';
  }
}

IconData _actionIconData(String action) {
  switch (_actionIcon(action)) {
    case 'add_circle': return Icons.add_circle_outline;
    case 'person_add': return Icons.person_add_alt;
    case 'person_remove': return Icons.person_remove_outlined;
    case 'exit_to_app': return Icons.exit_to_app;
    case 'edit': return Icons.edit_outlined;
    case 'photo_camera': return Icons.photo_camera_outlined;
    case 'photo_off': return Icons.broken_image_outlined;
    case 'group': return Icons.group_outlined;
    case 'manage_accounts': return Icons.manage_accounts_outlined;
    case 'security': return Icons.security_outlined;
    case 'security_off': return Icons.enhanced_encryption_outlined;
    case 'link': return Icons.link;
    case 'link_off': return Icons.link_off;
    case 'settings': return Icons.settings_outlined;
    default: return Icons.info_outline;
  }
}

String _actionLabel(String action, bool greek) {
  switch (action) {
    case 'group_created': return greek ? 'Δημιουργία ομάδας' : 'Group created';
    case 'member_added': return greek ? 'Προσθήκη μέλους' : 'Member added';
    case 'member_removed': return greek ? 'Αφαίρεση μέλους' : 'Member removed';
    case 'member_left': return greek ? 'Αποχώρηση μέλους' : 'Member left';
    case 'group_name_changed': return greek ? 'Αλλαγή ονόματος' : 'Name changed';
    case 'group_avatar_changed': return greek ? 'Αλλαγή φωτογραφίας' : 'Avatar changed';
    case 'group_avatar_removed': return greek ? 'Αφαίρεση φωτογραφίας' : 'Avatar removed';
    case 'max_participants_changed': return greek ? 'Αλλαγή ορίου μελών' : 'Member limit changed';
    case 'role_changed': return greek ? 'Αλλαγή ρόλου' : 'Role changed';
    case 'permission_override_added': return greek ? 'Προσθήκη δικαιώματος' : 'Permission added';
    case 'permission_override_removed': return greek ? 'Αφαίρεση δικαιώματος' : 'Permission removed';
    case 'invite_created': return greek ? 'Δημιουργία πρόσκλησης' : 'Invite created';
    case 'invite_revoked': return greek ? 'Ανάκληση πρόσκλησης' : 'Invite revoked';
    case 'settings_updated': return greek ? 'Ενημέρωση ρυθμίσεων' : 'Settings updated';
    default: return action;
  }
}

class GroupAuditLogScreen extends ConsumerWidget {
  final String chatId;
  const GroupAuditLogScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final logsAsync = ref.watch(auditLogStreamProvider(chatId));

    return Scaffold(
      appBar: AppBar(
        title: Text(greek ? 'Αρχείο Καταγραφής' : 'Audit Log'),
      ),
      body: logsAsync.when(
        loading: () => Center(child: LoadingView(message: greek ? 'Φόρτωση αρχείου...' : 'Loading audit log...')),
        error: (e, s) {
          DebugConfig.error('AuditLog stream error', data: e, exception: s);
          return Center(
            child: ErrorView(
              message: greek ? 'Σφάλμα φόρτωσης αρχείου' : 'Failed to load audit log',
              onRetry: () => ref.invalidate(auditLogStreamProvider(chatId)),
            ),
          );
        },
        data: (entries) => entries.isEmpty
            ? Center(child: EmptyView(
                icon: Icons.history,
                message: greek ? 'Δεν υπάρχουν ακόμα καταχωρήσεις' : 'No audit entries yet',
              ))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final w = ResponsiveUtils.resolveWidth(context, constraints);
                  final pad = ResponsiveUtils.paddingValueFromWidth(w);
                  return ListView.separated(
                    padding: EdgeInsets.all(pad),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      return _AuditLogTile(entry: entry, greek: greek, theme: theme);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _AuditLogTile extends ConsumerWidget {
  final AuditLogEntry entry;
  final bool greek;
  final ThemeData theme;

  const _AuditLogTile({
    required this.entry,
    required this.greek,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatData = ref.watch(chatDocProvider(entry.chatId)).asData?.value?.data() as Map<String, dynamic>?;
    final nicknames = chatData?['participantNicknames'] as Map<String, dynamic>?;
    final actorNick = entry.actorName ?? nicknames?[entry.actor] as String? ?? entry.actor;
    final targetNick = entry.targetUid != null ? (nicknames?[entry.targetUid] as String?) : null;

    String displayDetails = entry.details ?? '';
    if (targetNick != null && entry.details == null) {
      displayDetails = targetNick;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          _actionIconData(entry.action),
          color: theme.colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        _actionLabel(entry.action, greek),
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            actorNick,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          if (displayDetails.isNotEmpty)
            Text(
              displayDetails,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(180)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: entry.timestamp != null
          ? Text(
              L10n.formatDateTime(context, entry.timestamp!),
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            )
          : null,
    );
  }
}
