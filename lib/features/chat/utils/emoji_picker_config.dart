import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/responsive_utils.dart';

class EmojiPickerConfig {
  EmojiPickerConfig._();

  static Config create(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final greek = L10n.isGreek(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    DebugConfig.log(DebugConfig.uiInteraction,
        'EmojiPickerConfig: isDark=$isDark greek=$greek');

    return Config(
      height: null,
      locale: greek ? const Locale('el') : const Locale('en'),
      checkPlatformCompatibility: true,
      emojiViewConfig: EmojiViewConfig(
        backgroundColor: surface,
        emojiSizeMax: 28.0,
        buttonMode: ButtonMode.MATERIAL,
        noRecents: Text(
          greek ? 'Χωρίς πρόσφατα' : 'No Recents',
          style: TextStyle(fontSize: 20, color: onSurface.withAlpha(64)),
          textAlign: TextAlign.center,
        ),
      ),
      categoryViewConfig: CategoryViewConfig(
        backgroundColor: surface,
        indicatorColor: primary,
        iconColor: onSurface.withAlpha(128),
        iconColorSelected: primary,
        dividerColor: theme.dividerColor,
        backspaceColor: onSurface.withAlpha(128),
        recentTabBehavior: RecentTabBehavior.RECENT,
      ),
      bottomActionBarConfig: BottomActionBarConfig(
        showBackspaceButton: true,
        showSearchViewButton: true,
        backgroundColor: surface,
        buttonIconColor: onSurface,
      ),
      searchViewConfig: SearchViewConfig(
        backgroundColor: surface,
        buttonIconColor: onSurface,
        hintText: greek ? 'Αναζήτηση emoji...' : 'Search emoji...',
        hintTextStyle: TextStyle(color: onSurface.withAlpha(128)),
        inputTextStyle: TextStyle(color: onSurface),
      ),
      skinToneConfig: SkinToneConfig(
        enabled: true,
        dialogBackgroundColor: surface,
        indicatorColor: primary,
      ),
    );
  }

  static double responsiveHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final orientation = MediaQuery.of(context).orientation;

    if (orientation == Orientation.landscape) {
      return screenHeight * 0.55;
    }

    final bp = ResponsiveUtils.breakpoint(context);
    switch (bp) {
      case ScreenBreakpoint.mobile:
        return screenHeight * 0.35;
      case ScreenBreakpoint.tablet:
        return screenHeight * 0.30;
      case ScreenBreakpoint.desktop:
        return screenHeight * 0.25;
    }
  }
}
