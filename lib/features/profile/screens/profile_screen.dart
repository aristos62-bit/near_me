import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../repositories/auth_repository.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isTogglingPublish = false;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileScreen init');
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final user = ref.watch(authStateProvider).value;
    final canComm = AuthRepository.canUserCommunicate(user);
    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileScreen build: canComm=$canComm');

    return Scaffold(
      appBar: AppBar(
        title: Text(isGreek ? 'Προφίλ' : 'Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: isGreek ? 'Ρυθμίσεις' : 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: LoadingView()),
        error: (e, s) {
          DebugConfig.error('ProfileScreen load failed', data: e, exception: s);
          return Center(
            child: ErrorView(
              message: L10n.localizedMessage(context, 'Σφάλμα φόρτωσης προφίλ / Failed to load profile'),
              onRetry: () => ref.invalidate(currentProfileProvider),
            ),
          );
        },
        data: (profile) {
          if (profile == null) return _buildEmptyState(isGreek);
          return _buildProfileView(profile, isGreek, canComm);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isGreek) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 72, color: Theme.of(context).colorScheme.primary.withAlpha(100)),
            const SizedBox(height: 20),
            Text(isGreek ? 'Δεν έχεις δημιουργήσει προφίλ ακόμα' : 'No profile yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              isGreek
                  ? 'Δημιούργησε ένα προφίλ για να συνδεθείς με άτομα κοντά σου'
                  : 'Create a profile to connect with people nearby',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/profile/edit'),
              icon: const Icon(Icons.add),
              label: Text(isGreek ? 'Δημιουργία Προφίλ' : 'Create Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView(UserProfileTableData profile, bool isGreek, bool canComm) {
    final age = profile.birthYear != null ? DateTime.now().year - profile.birthYear! : null;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = ResponsiveUtils.maxContentWidthFromWidth(
              ResponsiveUtils.resolveWidth(context, constraints),
            );
            // ── ΠΡΟΣΩΡΙΝΟ DIAGNOSTIC LOG — Πρόβλημα 2 (θα αφαιρεθεί μετά) ──
            DebugConfig.log(DebugConfig.uiRebuild,
                'ProfileScreen LayoutBuilder REBUILT — '
                    'constraints=$constraints, '
                    'time=${DateTime.now().toIso8601String().substring(11, 23)}');
            return SizedBox(width: w, child: Column(
              children: [
                GradientHeader(
                  icon: Icons.person,
                  title: profile.nickname ?? (isGreek ? 'Χωρίς όνομα' : 'Unnamed'),
                  subtitle: [
                    if (age != null) '$age ${isGreek ? 'ετών' : 'yo'}',
                    if (profile.city != null && profile.city!.isNotEmpty) profile.city!,
                    if (profile.gender != null && profile.gender!.isNotEmpty)
                      L10n.genderLabel(profile.gender!, isGreek: isGreek),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: profile.avatarUrl!,
                            width: 64, height: 64, fit: BoxFit.cover,
                            placeholder: (ctx, url) => SizedBox(width: 64, height: 64,
                              child: Icon(Icons.person, color: Colors.white.withAlpha(100), size: 32)),
                            errorWidget: (ctx, url, err) => SizedBox(width: 64, height: 64,
                              child: Icon(Icons.person, color: Colors.white.withAlpha(100), size: 32)),
                          ),
                        )
                      : null,
                ),
                if (profile.bio != null && profile.bio!.isNotEmpty)
                  _infoCard(theme, Icons.article_outlined,
                      isGreek ? 'Σχετικά' : 'About', profile.bio!),
                _infoCard(theme, Icons.interests_outlined,
                    isGreek ? 'Ενδιαφέροντα' : 'Interests',
                    profile.interests?.map((i) => L10n.interestLabel(i, isGreek: isGreek)).join(', ') ??
                        (isGreek ? 'Δεν έχουν οριστεί' : 'Not set')),
                if (profile.lookingFor != null && profile.lookingFor!.isNotEmpty)
                  _infoCard(theme, Icons.explore_outlined,
                      isGreek ? 'Αναζητά' : 'Looking For',
                      L10n.lookingForLabel(profile.lookingFor!, isGreek: isGreek)),
                if (canComm)
                  _buildPublishToggle(profile, theme, isGreek)
                else
                  _buildVerifyBanner(theme, isGreek, canComm),
                const SizedBox(height: 8),
                _buildMenu(theme, isGreek),
                const SizedBox(height: 32),
              ],
            ));
          },
        ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, IconData icon, String title, String content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(content, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishToggle(UserProfileTableData profile, ThemeData theme, bool isGreek) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: SwitchListTile(
          secondary: Icon(profile.isPublished ? Icons.public : Icons.public_off,
              color: profile.isPublished ? const Color(0xFF4CAF50) : theme.colorScheme.onSurfaceVariant),
          title: Text(profile.isPublished
              ? (isGreek ? 'Δημοσιευμένο' : 'Published')
              : (isGreek ? 'Μη δημοσιευμένο' : 'Unpublished')),
          subtitle: Text(profile.isPublished
              ? (isGreek ? 'Το προφίλ σου είναι ορατό σε άλλους' : 'Your profile is visible to others')
              : (isGreek ? 'Το προφίλ σου δεν είναι ορατό' : 'Your profile is not visible')),
          value: profile.isPublished,
          onChanged: _isTogglingPublish ? null : (v) => _togglePublish(v, profile, isGreek),
        ),
      ),
    );
  }

  Widget _buildVerifyBanner(ThemeData theme, bool isGreek, bool canComm) {
    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileScreen: showing verify banner (canComm=$canComm)');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 20,
                      color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isGreek ? 'Απαιτείται επαλήθευση' : 'Verification required',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isGreek
                    ? 'Για να δημοσιεύσεις το προφίλ σου και να συμμετέχεις στην κοινότητα, πρέπει πρώτα να επαληθεύσεις τον λογαριασμό σου.'
                    : 'To publish your profile and participate in the community, you need to verify your account first.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer.withAlpha(200)),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  DebugConfig.log(DebugConfig.uiInteraction, 'ProfileScreen: navigate to verify from banner');
                  context.push('/auth');
                },
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(isGreek ? 'Επαλήθευση Λογαριασμού' : 'Verify Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePublish(bool target, UserProfileTableData profile, bool isGreek) async {
    setState(() => _isTogglingPublish = true);
    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileScreen togglePublish: target=$target');
    try {
      final repo = ref.read(profileRepositoryProvider);
      if (target) {
        await repo.publish();
      } else {
        await repo.unpublish();
      }
      if (mounted) {
        AppMessenger.showSuccess(context, target
            ? L10n.localizedMessage(context, 'Το προφίλ δημοσιεύτηκε / Profile published')
            : L10n.localizedMessage(context, 'Το προφίλ αποσύρθηκε / Profile unpublished'));
      }
    } catch (e, s) {
      DebugConfig.error('ProfileScreen togglePublish failed', data: e, exception: s);
      if (mounted) {
        AppMessenger.showError(context, L10n.localizedMessage(context, 'Αποτυχία αλλαγής κατάστασης / Failed to update status'));
      }
    } finally {
      if (mounted) setState(() => _isTogglingPublish = false);
    }
  }

  Widget _buildMenu(ThemeData theme, bool isGreek) {
    final items = [
      _MenuItem(Icons.edit_outlined, 'Επεξεργασία', 'Edit', '/profile/edit'),
      _MenuItem(Icons.shield_outlined, 'Απόρρητο', 'Privacy', '/profile/privacy'),
      _MenuItem(Icons.history_outlined, 'Ιστορικό', 'Consent Log', '/profile/consent-log'),
      _MenuItem(Icons.mail_outline, 'Αιτήματα', 'Requests', '/requests'),
      _MenuItem(Icons.block_outlined, 'Αποκλεισμένοι', 'Blocked', '/profile/blocked'),
      _MenuItem(Icons.delete_forever_outlined, 'Διαγραφή', 'Delete', '/profile/delete'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: List.generate(items.length, (i) {
            final item = items[i];
            return Column(
              children: [
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: Icon(item.icon),
                  title: Text(isGreek ? item.labelEl : item.labelEn),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    DebugConfig.log(DebugConfig.uiInteraction, 'ProfileScreen menu: ${item.route}');
                    context.push(item.route);
                  },
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String labelEl;
  final String labelEn;
  final String route;
  const _MenuItem(this.icon, this.labelEl, this.labelEn, this.route);
}
