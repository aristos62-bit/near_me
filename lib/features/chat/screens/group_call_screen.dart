import 'package:flutter/material.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';

class GroupCallScreen extends StatelessWidget {
  final String chatId;
  final String? groupName;
  const GroupCallScreen({super.key, required this.chatId, this.groupName});

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);

    DebugConfig.log(DebugConfig.uiInteraction, 'GroupCallScreen: chat=$chatId groupName=$groupName');

    if (FeatureFlags.videoCallEnabled) {
      return Scaffold(
        appBar: AppBar(title: Text(groupName ?? chatId)),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveUtils.paddingValueFromWidth(
                ResponsiveUtils.resolveWidth(context, null))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(greek ? 'Group κλήση' : 'Group Call',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  greek
                      ? 'Η υποστήριξη group κλήσεων θα προστεθεί σύντομα'
                      : 'Group call support coming soon',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(groupName ?? chatId)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.paddingValueFromWidth(
              ResponsiveUtils.resolveWidth(context, null))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, size: 64,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                greek ? 'Οι κλήσεις δεν είναι διαθέσιμες' : 'Calls not available',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                greek
                    ? 'Αυτή η λειτουργία θα είναι διαθέσιμη σε μελλοντική ενημέρωση'
                    : 'This feature will be available in a future update',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
