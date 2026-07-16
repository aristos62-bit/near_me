import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../utils/emoji_picker_config.dart';

class EmojiPickerPanel extends StatefulWidget {
  final void Function(Category? category, Emoji emoji) onEmojiSelected;

  const EmojiPickerPanel({super.key, required this.onEmojiSelected});

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  Config? _cachedConfig;
  bool? _cachedIsDark;
  bool? _cachedIsGreek;

  Config _getConfig(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final greek = L10n.isGreek(context);

    if (_cachedConfig != null && _cachedIsDark == isDark && _cachedIsGreek == greek) {
      return _cachedConfig!;
    }

    DebugConfig.log(DebugConfig.uiInteraction,
        'EmojiPickerPanel: _getConfig isDark=$isDark greek=$greek');

    _cachedConfig = EmojiPickerConfig.create(context);
    _cachedIsDark = isDark;
    _cachedIsGreek = greek;
    return _cachedConfig!;
  }

  @override
  void dispose() {
    DebugConfig.log(DebugConfig.uiInteraction, 'EmojiPickerPanelState dispose');
    _cachedConfig = null;
    super.dispose();
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    try {
      widget.onEmojiSelected(category, emoji);
    } catch (e) {
      DebugConfig.error('EmojiPickerPanel: onEmojiSelected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.log(DebugConfig.uiInteraction, 'EmojiPickerPanel build');
    return SizedBox(
      height: EmojiPickerConfig.responsiveHeight(context),
      child: EmojiPicker(
        onEmojiSelected: _onEmojiSelected,
        config: _getConfig(context),
      ),
    );
  }
}
