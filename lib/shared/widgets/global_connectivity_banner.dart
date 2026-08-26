import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connectivity_provider.dart';
import '../../core/debug/debug_config.dart';
import '../../core/l10n/l10n.dart';

class GlobalConnectivityBanner extends ConsumerWidget {
  const GlobalConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).asData?.value ?? true;
    if (isOnline) return const SizedBox.shrink();

    DebugConfig.log(DebugConfig.networkConnectivity,
        'GlobalConnectivityBanner: SHOWING offline overlay');

    final isGreek = L10n.isGreek(context);
    final topPadding = MediaQuery.viewPaddingOf(context).top;

    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      child: MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        content: Text(
          isGreek ? 'Εκτός σύνδεσης' : 'Offline',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: const Icon(Icons.wifi_off, color: Colors.white, size: 20),
        backgroundColor: Colors.orange.shade800,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'OK',
              style: TextStyle(color: Colors.orange.shade200),
            ),
          ),
        ],
      ),
    );
  }
}
