import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/block_provider.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGreek = L10n.isGreek(context);
    final uid = ref.watch(authStateProvider).value?.uid;
    DebugConfig.log(DebugConfig.uiInteraction, 'BlockedUsersScreen build');

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(isGreek ? 'Μπλοκαρισμένοι' : 'Blocked')),
        body: const Center(child: Text('')),
      );
    }

    final blockedAsync = ref.watch(blockedUidsProvider(uid));

    return Scaffold(
      appBar: AppBar(title: Text(isGreek ? 'Μπλοκαρισμένοι Χρήστες' : 'Blocked Users')),
      body: Center(
        child: SizedBox(
          width: ResponsiveUtils.maxContentWidth(context),
          child: blockedAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: L10n.localizedMessage(context, 'Σφάλμα φόρτωσης / Failed to load'),
              onRetry: () => ref.invalidate(blockedUidsProvider(uid)),
            ),
            data: (blockedUids) {
              if (blockedUids.isEmpty) {
                return EmptyView(
                  icon: Icons.block_outlined,
                  message: L10n.localizedMessage(context, 'Δεν έχεις μπλοκάρει κανέναν χρήστη / No blocked users'),
                  actionLabel: null,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(blockedUidsProvider(uid)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: blockedUids.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final blockedUid = blockedUids.elementAt(index);
                    return _BlockedUserTile(blockedUid: blockedUid, isGreek: isGreek);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerWidget {
  final String blockedUid;
  final bool isGreek;

  const _BlockedUserTile({required this.blockedUid, required this.isGreek});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    DebugConfig.log(DebugConfig.uiInteraction, '_BlockedUserTile build: $blockedUid');

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users').doc(blockedUid).collection('public').doc('profile')
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final nickname = data?['nickname'] as String? ?? blockedUid;
        final city = data?['city'] as String?;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withAlpha(25),
            child: Text(nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(nickname, style: AppTypography.bodyMedium),
          subtitle: city != null && city.isNotEmpty
              ? Text(city, style: AppTypography.caption)
              : null,
          trailing: TextButton.icon(
            onPressed: () async {
              if (uid == null) return;
              DebugConfig.log(DebugConfig.uiInteraction, '_BlockedUserTile unblock: $blockedUid');
              await ref.read(blockActionsProvider).unblock(uid, blockedUid);
              if (context.mounted) {
                AppMessenger.showSuccess(context,
                    L10n.localizedMessage(context, 'Ξεμπλοκαρίστηκε / Unblocked'));
              }
            },
            icon: const Icon(Icons.lock_open_outlined, size: 18),
            label: Text(isGreek ? 'Ξεμπλοκάρισμα' : 'Unblock'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        );
      },
    );
  }
}
