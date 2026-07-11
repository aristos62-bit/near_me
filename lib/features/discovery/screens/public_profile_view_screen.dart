import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/auth_repository.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/report_user_dialog.dart';
import '../widgets/public_profile_header.dart';
import '../providers/search_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../block/providers/block_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../report/providers/report_provider.dart';
import '../../chat/providers/chat_provider.dart';


class PublicProfileViewScreen extends ConsumerStatefulWidget {
  const PublicProfileViewScreen({super.key});

  @override
  ConsumerState<PublicProfileViewScreen> createState() =>
      _PublicProfileViewScreenState();
}

class _PublicProfileViewScreenState extends ConsumerState<PublicProfileViewScreen> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen init');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = GoRouterState.of(context).pathParameters['uid'];
    if (uid != null && uid != _uid) {
      _uid = uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final isGreek = L10n.isGreek(context);

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(
          child: Text(isGreek ? 'Δεν βρέθηκε χρήστης' : 'User not found'),
        ),
      );
    }

    final profileAsync = ref.watch(publicProfileStreamProvider(uid));

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const LoadingView(),
      ),
      error: (e, s) {
        DebugConfig.error('PublicProfileView stream error', data: e, exception: s);
        return Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: ErrorView(
            message: ErrorMessages.get('stream/load-error', L10n.isGreek(context)),
            onRetry: () => ref.invalidate(publicProfileStreamProvider(uid)),
          ),
        );
      },
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: ErrorView(
              message: L10n.localizedMessage(context, 'Το προφίλ δεν βρέθηκε / Profile not found'),
            ),
          );
        }
        final theme = Theme.of(context);
        final searchState = ref.read(searchProvider);
        final distanceKm = searchState.status == SearchStatus.success
            ? searchState.distances[uid]
            : null;
        if (distanceKm != null) {
          DebugConfig.log(DebugConfig.repositoryResult,
              'PublicProfileView uid=$uid distance=${distanceKm.toStringAsFixed(1)}km');
        }
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final w = ResponsiveUtils.resolveWidth(context, constraints);
              return SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: ResponsiveUtils.maxContentWidthFromWidth(w),
                    child: Column(
                  children: [
                    PublicProfileHeader(profile: profile, uid: uid, distanceKm: distanceKm),
                    if (profile.photoUrls != null && profile.photoUrls!.isNotEmpty)
                      _buildPhotoGallery(profile, theme, isGreek),
                    _buildLookingForCard(profile, theme, isGreek),
                    _buildInterestsCard(profile, theme, isGreek),
                    _buildBioCard(profile, theme, isGreek),
                    _buildCommunicationCard(profile, theme, isGreek),
                    _buildContactCard(profile, theme, isGreek, uid),
                    _buildRequestButton(profile, theme, isGreek),
                    _buildInviteToGroupButton(theme, isGreek),
                    _buildBlockButton(theme, isGreek),
                    _buildReportButton(theme, isGreek),
                  ],
                ),
              ),
            ),
          );
          },
        ),
      );
      },
    );
  }

  Widget _sectionCard({required Widget child, required String title, required IconData icon}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(PublicProfile profile, ThemeData theme, bool isGreek) {
    final photos = profile.photoUrls!.take(9).toList();
    return _sectionCard(
      icon: Icons.photo_library_outlined,
      title: isGreek ? 'Φωτογραφίες' : 'Photos',
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (ctx, i) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: photos[i], width: 100, height: 100, fit: BoxFit.cover,
              placeholder: (ctx, url) => Container(width: 100, height: 100,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant.withAlpha(80))),
              errorWidget: (ctx, url, err) => Container(width: 100, height: 100,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant.withAlpha(80))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLookingForCard(PublicProfile profile, ThemeData theme, bool isGreek) {
    final value = profile.lookingFor;
    if (value == null) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.explore_outlined,
      title: isGreek ? 'Ενδιαφέρεται για' : 'Looking For',
      child: Chip(
        label: Text(L10n.lookingForLabel(value, isGreek: isGreek)),
        avatar: Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildInterestsCard(PublicProfile profile, ThemeData theme, bool isGreek) {
    final interests = profile.interests;
    if (interests == null || interests.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.interests_outlined,
      title: isGreek ? 'Ενδιαφέροντα' : 'Interests',
      child: Wrap(
        spacing: 8, runSpacing: 6,
        children: interests.map((i) => Chip(
          label: Text(L10n.interestLabel(i, isGreek: isGreek), style: const TextStyle(fontSize: 13)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList(),
      ),
    );
  }

  Widget _buildBioCard(PublicProfile profile, ThemeData theme, bool isGreek) {
    final bio = profile.bio;
    if (bio == null || bio.isEmpty) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.article_outlined,
      title: isGreek ? 'Σχετικά' : 'About',
      child: Text(bio, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _buildCommunicationCard(PublicProfile profile, ThemeData theme, bool isGreek) {
    return _sectionCard(
      icon: Icons.chat_outlined,
      title: isGreek ? 'Επικοινωνία' : 'Communication',
      child: Column(
        children: [
          _commRow(
            icon: Icons.chat_bubble_outline,
            label: isGreek ? 'Απευθείας μηνύματα' : 'Direct Messages',
            allowed: profile.allowDirectChat, theme: theme, isGreek: isGreek,
          ),
          const SizedBox(height: 8),
          _commRow(
            icon: Icons.videocam_outlined,
            label: isGreek ? 'Βιντεοκλήση' : 'Video Call',
            allowed: profile.allowVideoCall, theme: theme, isGreek: isGreek,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
      PublicProfile profile, ThemeData theme, bool isGreek, String uid) {
    final hasEmail = profile.email != null && profile.email!.isNotEmpty;
    final hasPhone = profile.phone != null && profile.phone!.isNotEmpty;
    if (!hasEmail && !hasPhone) return const SizedBox.shrink();

    DebugConfig.log(DebugConfig.uiInteraction,
        'PublicProfileView: contact card shown for $uid '
        '(email=$hasEmail, phone=$hasPhone)');

    return _sectionCard(
      icon: Icons.contact_mail_outlined,
      title: isGreek ? 'Στοιχεία Επικοινωνίας' : 'Contact Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasEmail)
            _contactRow(
              icon: Icons.email_outlined,
              label: isGreek ? 'Email' : 'Email',
              value: profile.email!,
              theme: theme,
            ),
          if (hasEmail && hasPhone) const SizedBox(height: 10),
          if (hasPhone)
            _contactRow(
              icon: Icons.phone_outlined,
              label: isGreek ? 'Τηλέφωνο' : 'Phone',
              value: profile.phone!,
              theme: theme,
            ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text('$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _commRow({required IconData icon, required String label, required bool allowed, required ThemeData theme, required bool isGreek}) {
    return Row(
      children: [
        Icon(allowed ? Icons.check_circle : Icons.cancel_outlined, size: 20,
            color: allowed ? const Color(0xFF4CAF50) : theme.colorScheme.onSurfaceVariant.withAlpha(120)),
        const SizedBox(width: 10),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(allowed ? (isGreek ? 'Ναι' : 'Yes') : (isGreek ? 'Όχι' : 'No'),
            style: theme.textTheme.bodySmall?.copyWith(
                color: allowed ? const Color(0xFF4CAF50) : theme.colorScheme.onSurfaceVariant.withAlpha(120))),
      ],
    );
  }

  Widget _buildRequestButton(PublicProfile profile, ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final currentUid = user?.uid;
    final isSelf = currentUid != null && currentUid == _uid;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || isSelf || _uid == null) {
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
            DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen send request: $_uid');
            context.push('/requests/send/$_uid');
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

  Widget _buildInviteToGroupButton(ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final currentUid = user?.uid;
    final isSelf = currentUid != null && currentUid == _uid;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || isSelf || _uid == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showGroupPickerSheet(isGreek),
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

  Future<void> _showGroupPickerSheet(bool isGreek) async {
    final uidToInvite = _uid;
    if (uidToInvite == null) return;

    final chats = ref.read(chatsProvider).asData?.value ?? [];
    final groupChats = chats.where((c) => c.isGroupChat).toList();

    if (groupChats.isEmpty) {
      AppMessenger.showInfo(context, isGreek
          ? 'Δεν έχεις ομάδες για πρόσκληση'
          : 'No groups to invite to');
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

    if (result == null || !mounted) return;

    final success = await ref.read(chatActionsProvider.notifier)
        .addParticipant(result, uidToInvite);
    if (!mounted) return;
    if (success) {
      AppMessenger.showSuccess(context, isGreek
          ? 'Προστέθηκε στην ομάδα'
          : 'Invited to group');
    } else {
      final state = ref.read(chatActionsProvider);
      AppMessenger.showError(context, state.errorMessage ??
          (isGreek ? 'Αποτυχία πρόσκλησης' : 'Failed to invite'));
    }
  }

  Widget _buildReportButton(ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final currentUid = user?.uid;
    final isSelf = currentUid != null && currentUid == _uid;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || isSelf || _uid == null) {
      DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen: report button hidden (canComm=$canComm)');
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showReportDialog(isGreek),
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

  Future<void> _showReportDialog(bool isGreek) async {
    final reporterUid = _reporterUid;
    final uid = _uid;
    if (reporterUid == null || uid == null) {
      DebugConfig.warn('_showReportDialog: null reporterUid=$reporterUid uid=$uid');
      return;
    }

    final reason = await showReportUserDialog(context, isGreek);
    if (reason == null || !mounted) return;

    final confirm = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.localizedMessage(context, 'Επιβεβαίωση Αναφοράς / Confirm Report'),
      message: L10n.localizedMessage(context, 'Η αναφορά θα σταθεί ανώνυμα. Ο διαχειριστής θα την εξετάσει. / Your report will be submitted anonymously. An admin will review it.'),
      confirmLabel: isGreek ? 'Υποβολή' : 'Submit',
      cancelLabel: isGreek ? 'Ακύρωση' : 'Cancel',
      isDestructive: true,
    );

    if (!confirm || !mounted) return;

    DebugConfig.log(DebugConfig.uiInteraction,
        'Report: reporter=$reporterUid target=$uid reason=$reason');

    try {
      await ref.read(reportRepositoryProvider).submitReport(
        reporterUid: reporterUid,
        reportedUid: uid,
        reason: reason,
      );
      if (mounted) {
        AppMessenger.showSuccess(context,
            L10n.localizedMessage(context, 'Η αναφορά υποβλήθηκε / Report submitted'));
      }
    } catch (e, s) {
      DebugConfig.error('Report submission failed', data: e, exception: s);
      if (mounted) {
        AppMessenger.showError(context,
            L10n.localizedMessage(context, 'Αποτυχία υποβολής αναφοράς / Failed to submit report'));
      }
    }
  }

  String? get _reporterUid => ref.watch(authStateProvider).value?.uid;

  Widget _buildBlockButton(ThemeData theme, bool isGreek) {
    final user = ref.watch(authStateProvider).value;
    final canComm = AuthRepository.canUserCommunicate(user);
    if (!canComm || user == null || user.uid == _uid || _uid == null) {
      DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfileViewScreen: block button hidden (canComm=$canComm, userUid=${user?.uid})');
      return const SizedBox.shrink();
    }

    final blockedUids = ref.watch(blockedUidsProvider(user.uid)).value ?? {};
    final isBlocked = blockedUids.contains(_uid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            if (isBlocked) {
              DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfile unblock: $_uid');
                await ref.read(blockActionsProvider).unblock(user.uid, _uid!);
              if (mounted) {
                AppMessenger.showSuccess(context,
                    L10n.localizedMessage(context, 'Ξεμπλοκαρίστηκε / Unblocked'));
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
              if (confirm && mounted) {
                DebugConfig.log(DebugConfig.uiInteraction, 'PublicProfile block: $_uid');
                await ref.read(blockActionsProvider).block(user.uid, _uid!);
                if (mounted) {
                  AppMessenger.showSuccess(context,
                      L10n.localizedMessage(context, 'Μπλοκαρίστηκε / Blocked'));
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
