import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';

enum MediaAction { emoji, gif, photo, camera, record }

Future<MediaAction?> showMediaPickerSheet(
  BuildContext context,
) async {
  final greek = L10n.isGreek(context);
  final available = <MediaAction>[
    MediaAction.emoji,
    if (FeatureFlags.gifSupportEnabled) MediaAction.gif,
    if (FeatureFlags.mediaMessagesEnabled) ...[MediaAction.photo, MediaAction.camera],
    if (FeatureFlags.audioMessagesEnabled && !kIsWeb) MediaAction.record,
  ];

  if (available.length == 1) {
    DebugConfig.log(DebugConfig.uiInteraction,
        'MediaPickerSheet: only emoji available, skipping sheet');
    return available.first;
  }

  DebugConfig.log(DebugConfig.uiInteraction, 'MediaPickerSheet: shown');
  final result = await showModalBottomSheet<MediaAction>(
    context: context,
    builder: (_) => _MediaPickerContent(actions: available, greek: greek),
  );

  if (result == null) {
    DebugConfig.log(DebugConfig.uiInteraction,
        'MediaPickerSheet: dismissed without selection');
  }
  return result;
}

class _MediaPickerContent extends StatelessWidget {
  final List<MediaAction> actions;
  final bool greek;

  const _MediaPickerContent({
    required this.actions,
    required this.greek,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions.map((action) => _buildTile(context, theme, action)).toList(),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, ThemeData theme, MediaAction action) {
    final (icon, label) = switch (action) {
      MediaAction.emoji => (Icons.emoji_emotions_outlined,
          greek ? 'Emoji' : 'Emoji'),
      MediaAction.gif => (Icons.gif_box_outlined, 'GIF'),
      MediaAction.photo => (Icons.photo_outlined,
          greek ? 'Φωτογραφία' : 'Photo'),
      MediaAction.camera => (Icons.photo_camera_outlined,
          greek ? 'Κάμερα' : 'Camera'),
      MediaAction.record => (Icons.mic_outlined,
          greek ? 'Ηχογράφηση' : 'Record'),
    };

    return ListTile(
      leading: Icon(icon, size: 28),
      title: Text(label, style: theme.textTheme.bodyLarge),
      onTap: () {
        DebugConfig.log(DebugConfig.uiInteraction,
            'MediaPickerSheet: ${action.name} selected');
        Navigator.of(context).pop(action);
      },
    );
  }
}
