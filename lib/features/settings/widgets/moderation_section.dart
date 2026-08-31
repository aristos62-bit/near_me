import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../core/utils/app_messenger.dart';
import '../../../core/utils/error_messages.dart';
import '../providers/app_settings_provider.dart';

/// Τoggle + Slider "Θάμπωμα" — blur sigma 0/8/12/20 (reuse _AutoLockTile pattern)
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
        data: (s) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
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
            if (s.blurExplicitEnabled) _BlurSigmaTile(currentSigma: s.blurSigma),
          ],
        ),
      ),
    );
  }
}

class _BlurSigmaTile extends ConsumerStatefulWidget {
  final double currentSigma;
  const _BlurSigmaTile({required this.currentSigma});

  @override
  ConsumerState<_BlurSigmaTile> createState() => _BlurSigmaTileState();
}

class _BlurSigmaTileState extends ConsumerState<_BlurSigmaTile> {
  static const _sigmas = [0.0, 8.0, 12.0, 20.0];
  late int _selectedIndex;

  int _sigmaToIndex(double sigma) {
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < _sigmas.length; i++) {
      final diff = (sigma - _sigmas[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = _sigmaToIndex(widget.currentSigma);
  }

  @override
  void didUpdateWidget(covariant _BlurSigmaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentSigma != oldWidget.currentSigma) {
      _selectedIndex = _sigmaToIndex(widget.currentSigma);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGreek = L10n.isGreek(context);
    final sigma = _sigmas[_selectedIndex];

    return ResponsivePadding(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.blur_circular_outlined),
            title: Text(isGreek ? 'Ένταση θαμπώματος' : 'Blur intensity'),
            subtitle: Text(L10n.blurSigmaLabel(sigma, isGreek: isGreek)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('0', style: Theme.of(context).textTheme.bodySmall),
                Expanded(
                  child: Slider(
                    value: _selectedIndex.toDouble(),
                    min: 0,
                    max: 3,
                    divisions: 3,
                    label: L10n.blurSigmaLabel(sigma, isGreek: isGreek),
                    semanticFormatterCallback: (v) =>
                        L10n.blurSigmaLabel(_sigmas[v.round()], isGreek: isGreek),
                    onChanged: (v) {
                      final rounded = v.round();
                      if (rounded == _selectedIndex) return;
                      setState(() => _selectedIndex = rounded);
                      DebugConfig.log(DebugConfig.uiInteraction,
                          '_BlurSigmaTile: onChanged index=$rounded sigma=${_sigmas[rounded]}');
                    },
                    onChangeEnd: (v) async {
                      final idx = v.round();
                      final newSigma = _sigmas[idx];
                      DebugConfig.log(DebugConfig.uiInteraction,
                          '_BlurSigmaTile: onChangeEnd sigma=$newSigma');
                      await ref.read(appSettingsProvider.notifier).setBlurSigma(newSigma);
                      if (context.mounted) {
                        AppMessenger.showInfo(context,
                            ErrorMessages.get('settings/blur-on', isGreek));
                      }
                    },
                  ),
                ),
                Text('20', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
