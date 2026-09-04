import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../../../repositories/auth_repository.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/widgets/report_user_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../block/providers/block_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../report/providers/report_provider.dart';

class PublicProfileActions extends ConsumerWidget {
  final String uid;
  final PublicProfile profile;

  const PublicProfileActions({
    super.key,
    required this.uid,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGreek = L10n.isGreek(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildRequestButton(ref, context, theme, isGreek),
        _buildInviteToGroupButton(ref, context, theme, isGreek),
        _buildBlockButton(ref, context, theme, isGreek),
        _buildReportButton(ref, context, theme, isGreek),
      ],
    );
  }

  Widget _buildRequestButton(
      WidgetRef ref, BuildContext context, ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final currentUid = user?.uid;
    final isSelf = currentUid != null && currentUid == uid;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || isSelf) {
      DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen: request button hidden (canComm=$canComm, isSelf=$isSelf)');
      return const SizedBox.shrink();
    }
    if (!profile.allowDirectChat && !profile.allowVideoCall) {
      DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen: request button hidden (no comm enabled)');
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen send request: $uid');
            context.push('/requests/send/$uid');
          },
          icon: const Icon(Icons.send_outlined, size: 20),
          label: Text(isGreek ? 'Αποστολή Αιτήματος' : 'Send Request'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteToGroupButton(
      WidgetRef ref, BuildContext context, ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final currentUid = user?.uid;
    final isSelf = currentUid != null && currentUid == uid;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || isSelf) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showGroupPickerSheet(context, ref, isGreek),
          icon: const Icon(Icons.group_add_outlined, size: 20),
          label: Text(isGreek ? 'Πρόσκληση σε Ομάδα' : 'Invite to Group'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            side: BorderSide(color: theme.colorScheme.outline.withAlpha(120)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupPickerSheet(
      BuildContext context, WidgetRef ref, bool isGreek) async {
    final chats = ref.read(chatsProvider).asData?.value ?? [];
    final groupChats = chats.where((c) => c.isGroupChat).toList();

    if (groupChats.isEmpty) {
      AppMessenger.showInfo(context, ErrorMessages.get('profile/no-groups-to-invite', isGreek));
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              isGreek ? 'Επιλογή Ομάδας' : 'Select Group',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ...groupChats.map((chat) => ListTile(
            leading: CircleAvatar(
              backgroundImage: chat.groupAvatarUrl != null ? CachedNetworkImageProvider(chat.groupAvatarUrl!) : null,
              child: chat.groupAvatarUrl == null ? const Icon(Icons.group) : null,
            ),
            title: Text(chat.groupName ?? chat.chatId ?? ''),
            subtitle: Text('${chat.participantCount} members'),
            onTap: () => Navigator.of(ctx).pop(chat.chatId),
          )),
        ],
      ),
    );

    if (result == null || !context.mounted) return;

    final success = await ref.read(chatActionsProvider.notifier)
        .addParticipant(result, uid);
    if (!context.mounted) return;
    if (success) {
      AppMessenger.showSuccess(context, ErrorMessages.get('profile/invited-to-group', isGreek));
    } else {
      final state = ref.read(chatActionsProvider);
      AppMessenger.showError(context, state.errorMessage ??
          ErrorMessages.get('profile/invite-failed', isGreek));
    }
  }

  Widget _buildReportButton(
      WidgetRef ref, BuildContext context, ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final currentUid = user?.uid;
    final isSelf = currentUid != null && currentUid == uid;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || isSelf) {
      DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen: report button hidden (canComm=$canComm)');
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showReportDialog(context, ref, isGreek),
          icon: const Icon(Icons.flag_outlined, size: 20),
          label: Text(isGreek ? 'Αναφορά' : 'Report'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            side: BorderSide(color: theme.colorScheme.outline.withAlpha(120)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _showReportDialog(
      BuildContext context, WidgetRef ref, bool isGreek) async {
    final reporterUid = ref.read(authStateProvider).value?.uid;
    if (reporterUid == null) {
      DebugConfig.warn('_showReportDialog: null reporterUid=$reporterUid uid=$uid');
      return;
    }

    final reason = await showReportUserDialog(context, isGreek);
    if (reason == null || !context.mounted) return;

    final confirm = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Επιβεβαίωση Αναφοράς / Confirm Report'),
      message: L10n.localizedMessage(context, 'Η αναφορά θα σταθεί ανώνυμα. Ο διαχειριστής θα την εξετάσει. / Your report will be submitted anonymously. An admin will review it.'),
      confirmLabel: isGreek ? 'Υποβολή' : 'Submit',
      cancelLabel: isGreek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );

    if (!confirm || !context.mounted) return;

    DebugConfig.log(DebugConfig.uiInteraction,
        'Report: reporter=$reporterUid target=$uid reason=$reason');

    try {
      await ref.read(reportRepositoryProvider).submitReport(
        reporterUid: reporterUid,
        reportedUid: uid,
        reason: reason,
      );
      if (context.mounted) {
        AppMessenger.showSuccess(context,
            ErrorMessages.get('report/submitted', L10n.isGreek(context)));
      }
    } catch (e, s) {
      DebugConfig.error('Report submission failed', data: e, exception: s);
      if (context.mounted) {
        AppMessenger.showError(context,
            ErrorMessages.get('report/submit-failed', L10n.isGreek(context)));
      }
    }
  }

  Widget _buildBlockButton(
      WidgetRef ref, BuildContext context, ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || user == null || user.uid == uid) {
      DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen: block button hidden (canComm=$canComm, userUid=${user?.uid})');
      return const SizedBox.shrink();
    }

    final blockedUids = ref.watch(blockedUidsProvider(user.uid)).value ?? {};
    final isBlocked = blockedUids.contains(uid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            if (isBlocked) {
              DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfile unblock: $uid');
              await ref.read(blockActionsProvider).unblock(user.uid, uid);
              if (context.mounted) {
                AppMessenger.showSuccess(context,
                    ErrorMessages.get('block/unblocked', L10n.isGreek(context)));
              }
            } else {
              final confirm = await AppMessenger.showConfirmDialog(
                context,
                title: L10n.localizedMessage(context, 'Μπλοκάρισμα Χρήστη / Block User'),
                message: L10n.localizedMessage(context, 'Ο χρήστης δεν θα εμφανίζεται στα αποτελέσματα αναζήτησης. Μπορείς να τον ξεμπλοκάρεις αργότερα. / This user will not appear in search results. You can unblock them later.'),
                confirmLabel: isGreek ? 'Μπλοκάρισμα' : 'Block',
                cancelLabel: isGreek ? 'Ακύρωση' : 'Cancel',
                isDestructive: true,
              );
              if (confirm && context.mounted) {
                DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfile block: $uid');
                await ref.read(blockActionsProvider).block(user.uid, uid);
                if (context.mounted) {
                  AppMessenger.showSuccess(context,
                      ErrorMessages.get('block/blocked', L10n.isGreek(context)));
                }
              }
            }
          },
          icon: Icon(isBlocked ? Icons.lock_open_outlined : Icons.block_outlined, size: 20),
          label: Text(isBlocked
              ? (isGreek ? 'Ξεμπλοκάρισμα' : 'Unblock')
              : (isGreek ? 'Μπλοκάρισμα' : 'Block')),
          style: OutlinedButton.styleFrom(
            foregroundColor: isBlocked ? null : theme.colorScheme.error,
            side: BorderSide(color: isBlocked ? theme.dividerColor : theme.colorScheme.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
