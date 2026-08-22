import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/connectivity_guard.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/local/database.dart';
import '../../../repositories/auth_repository.dart';
import '../../../shared/models/public_profile.dart';
import '../../../shared/utils/help_request_config.dart';
import '../../../shared/widgets/app_state_widget.dart';
import '../../../shared/widgets/chip_selector.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

/// Ανοίγει το bottom sheet του SOS (sos.md §5.2).
/// Responsive (ResponsiveUtils), keyboard handling event-driven (viewInsets),
/// eligibility από πραγματικές πηγές, write μέσω repository + consent log.
Future<void> showHelpRequestSheet(BuildContext context) {
  DebugConfig.log(DebugConfig.helpRequest, 'HelpRequestSheet: shown');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const HelpRequestSheet(),
  );
}

class HelpRequestSheet extends ConsumerStatefulWidget {
  const HelpRequestSheet({super.key});

  @override
  ConsumerState<HelpRequestSheet> createState() => _HelpRequestSheetState();
}

class _HelpRequestSheetState extends ConsumerState<HelpRequestSheet> {
  final _messageCtrl = TextEditingController();
  double _selectedRadius = HelpRequestConfig.defaultRadiusKm;
  bool _busy = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final isGreek = L10n.isGreek(context);
    if (!await ConnectivityGuard.ensure(context)) return;
    final message = _messageCtrl.text.trim();
    if (message.length > HelpRequestConfig.maxMessageLength) {
      if (mounted) {
        AppMessenger.showError(
            context, ErrorMessages.get('help/message-too-long', isGreek));
      }
      return;
    }
    setState(() => _busy = true);
    DebugConfig.log(DebugConfig.helpRequest,
        'HelpRequestSheet: activating radius=$_selectedRadius message="$message"');
    try {
      await ref.read(profileRepositoryProvider).setHelpRequest(
            active: true,
            message: message,
            radiusKm: _selectedRadius,
          );
      DebugConfig.log(DebugConfig.helpRequest, 'HelpRequestSheet: activated OK');
      if (mounted) {
        AppMessenger.showSuccess(
            context, ErrorMessages.get('help/activated', isGreek));
        Navigator.of(context).pop();
      }
    } catch (e) {
      DebugConfig.error('HelpRequestSheet: activate failed', data: e);
      if (mounted) {
        AppMessenger.showError(
          context,
          ErrorMessages.get(
              AppException.toFriendlyMessage(e, domain: 'help'), isGreek),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    final isGreek = L10n.isGreek(context);
    if (!await ConnectivityGuard.ensure(context)) return;
    if (!mounted) return;
    final confirmed = await AppMessenger.showConfirmDialog(
      context,
      title: L10n.helpDeactivateLabel(isGreek: isGreek),
      message: isGreek
          ? 'Να απενεργοποιηθεί η επείγουσα βοήθεια;'
          : 'Deactivate emergency help?',
      confirmLabel: L10n.helpDeactivateLabel(isGreek: isGreek),
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    DebugConfig.log(DebugConfig.helpRequest, 'HelpRequestSheet: deactivating');
    try {
      await ref.read(profileRepositoryProvider).setHelpRequest(active: false);
      DebugConfig.log(DebugConfig.helpRequest, 'HelpRequestSheet: deactivated OK');
      if (mounted) {
        AppMessenger.showSuccess(
            context, ErrorMessages.get('help/deactivated', isGreek));
        Navigator.of(context).pop();
      }
    } catch (e) {
      DebugConfig.error('HelpRequestSheet: deactivate failed', data: e);
      if (mounted) {
        AppMessenger.showError(
          context,
          ErrorMessages.get(
              AppException.toFriendlyMessage(e, domain: 'help'), isGreek),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goFix(String route) {
    DebugConfig.log(DebugConfig.helpRequest, 'HelpRequestSheet: fix → $route');
    Navigator.of(context).pop();
    context.push(route);
  }

  String _requirementLabel(String key, bool isGreek) {
    switch (key) {
      case 'verify':
        return isGreek ? 'Επαλήθευση λογαριασμού' : 'Account verification';
      case 'publish':
        return isGreek ? 'Δημοσιευμένο προφίλ' : 'Published profile';
      case 'gps':
        return isGreek ? 'Τοποθεσία GPS' : 'GPS location';
      case 'channel':
        return isGreek ? 'Κανάλι επικοινωνίας' : 'Communication channel';
      case 'visibleLocation':
        return isGreek ? 'Ορατή τοποθεσία' : 'Visible location';
    }
    return key;
  }

  String _fixLabel(String key, bool isGreek) {
    switch (key) {
      case 'verify':
        return isGreek ? 'Επαλήθευση' : 'Verify';
      case 'publish':
        return isGreek ? 'Δημοσίευση' : 'Publish';
      case 'gps':
        return isGreek ? 'GPS' : 'GPS';
      case 'channel':
        return isGreek ? 'Άνοιξε κανάλι' : 'Open channel';
      case 'visibleLocation':
        return isGreek ? 'Κάνε ορατή' : 'Make visible';
    }
    return key;
  }

  String _fixRoute(String key) {
    switch (key) {
      case 'verify':
        return '/auth';
      case 'publish':
        return '/profile';
      case 'gps':
        return '/profile/edit';
      case 'channel':
        return '/profile/privacy';
      case 'visibleLocation':
        return '/profile/privacy';
    }
    return '/profile';
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final uid = user?.uid ?? '';
    final profileAsync = ref.watch(currentProfileProvider);
    final pubAsync = ref.watch(publicProfileStreamProvider(uid));

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = ResponsiveUtils.resolveWidth(context, constraints);
          final pad = ResponsiveUtils.paddingValueFromWidth(w);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme, isGreek),
                const SizedBox(height: 20),
                if (profileAsync.isLoading || pubAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: LoadingView(),
                  )
                else
                  _buildBody(theme, isGreek, user, profileAsync.value,
                      pubAsync.value),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isGreek) {
    return Row(
      children: [
        Image.asset('assets/icons/sos2.webp', width: 36, height: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            L10n.helpRequestTitle(isGreek: isGreek),
            style: theme.textTheme.titleLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    ThemeData theme,
    bool isGreek,
    User? user,
    UserProfileTableData? profile,
    PublicProfile? pub,
  ) {
    if (user == null) {
      return const SizedBox.shrink();
    }
    final canComm = AuthRepository.canUserCommunicate(user);
    final isPublished = profile?.isPublished == true;
    final hasGps = profile?.latitudeExact != null;
    final hasChannel = HelpRequestConfig.hasChannel(pub);
    final hasVisibleLocation = pub?.geoHash != null;
    final eligible = HelpRequestConfig.canRequestHelp(
      canComm: canComm,
      isPublished: isPublished,
      hasGps: hasGps,
      hasChannel: hasChannel,
      hasVisibleLocation: hasVisibleLocation,
    );
    final active = pub?.helpRequest?.active == true;

    if (active) {
      return _buildActive(theme, isGreek, pub!.helpRequest!);
    }
    if (!eligible) {
      final missing = HelpRequestConfig.missingRequirements(
        canComm: canComm,
        isPublished: isPublished,
        hasGps: hasGps,
        hasChannel: hasChannel,
        hasVisibleLocation: hasVisibleLocation,
      );
      return _buildRequirements(theme, isGreek, missing);
    }
    return _buildSettings(theme, isGreek);
  }

  Widget _buildSettings(ThemeData theme, bool isGreek) {
    final radiusLabels = <String, String>{
      for (final r in HelpRequestConfig.radiusOptions) '${r.toInt()}': '${r.toInt()} km',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(L10n.helpDistanceLabel(isGreek: isGreek),
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ChipSelector(
          options:
              HelpRequestConfig.radiusOptions.map((r) => '${r.toInt()}').toList(),
          selectedValue: '${_selectedRadius.toInt()}',
          labels: radiusLabels,
          onSelected: (v) {
            if (v == null) return;
            setState(() => _selectedRadius = double.parse(v));
            DebugConfig.log(DebugConfig.helpRequest,
                'HelpRequestSheet: radius selected=$_selectedRadius');
          },
        ),
        const SizedBox(height: 20),
        Text(L10n.helpMessageLabel(isGreek: isGreek),
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _messageCtrl,
          maxLength: HelpRequestConfig.maxMessageLength,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: isGreek
                ? 'Περιγράψε σύντομα τι χρειάζεσαι'
                : 'Briefly describe what you need',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _activate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sos),
          label: Text(L10n.helpActivateLabel(isGreek: isGreek)),
        ),
      ],
    );
  }

  Widget _buildActive(ThemeData theme, bool isGreek, HelpRequest h) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.error),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sos, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    L10n.needsHelpLabel(isGreek: isGreek),
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (h.message != null && h.message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(h.message!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 8),
              Text(
                '${L10n.helpDistanceLabel(isGreek: isGreek)}: ${h.radiusKm.toInt()} km',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _deactivate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sos_outlined),
          label: Text(L10n.helpDeactivateLabel(isGreek: isGreek)),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirements(
      ThemeData theme, bool isGreek, List<String> missing) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(L10n.helpRequirementsTitle(isGreek: isGreek),
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...missing.map(
          (key) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(_requirementLabel(key, isGreek),
                      style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _goFix(_fixRoute(key)),
                  child: Text(_fixLabel(key, isGreek)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
