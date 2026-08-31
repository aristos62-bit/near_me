import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../providers/app_settings_provider.dart';

/// Τoggle "Θάμπωμα ακατάλληλου περιεχομένου" — blur explicit (POSSIBLE/LIKELY)
/// φωτογραφιών σε profile avatars, gallery, group avatars και chat εικόνες.
class ModerationSection extends ConsumerWidget {
  const ModerationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.contentModerationEnabled) return const SizedBox.shrink();
    final isGreek = L10n.isGreek(context);
    final async = ref.watch(appSettingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const ListTile(
          leading: Icon(Icons.blur_on_outlined),
          title: Text('...'),
        ),
        error: (e, _) => ListTile(
          leading: const Icon(Icons.blur_on_outlined),
          title: Text(isGreek ? 'Σφάλμα φόρτωσης' : 'Load error'),
        ),
        data: (s) => SwitchListTile(
          secondary: const Icon(Icons.blur_on_outlined),
          title: Text(isGreek ? 'Θάμπωμα ακατάλληλου περιεχομένου' : 'Blur explicit content'),
          subtitle: Text(isGreek
              ? 'Θάμπωμα φωτογραφιών με ενδείξεις POSSIBLE/LIKELY'
              : 'Blur photos flagged POSSIBLE/LIKELY'),
          value: s.blurExplicitEnabled,
          onChanged: (v) async {
            DebugConfig.log(DebugConfig.uiInteraction,
                'ModerationSection: blurExplicitEnabled=$v');
            await ref.read(appSettingsProvider.notifier).setBlurExplicit(v);
            if (context.mounted) {
              AppMessenger.showInfo(context,
                  ErrorMessages.get(v ? 'settings/blur-on' : 'settings/blur-off', isGreek));
            }
          },
        ),
      ),
    );
  }
}
