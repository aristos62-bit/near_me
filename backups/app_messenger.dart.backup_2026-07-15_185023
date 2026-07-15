import 'package:flutter/material.dart';
import '../debug/debug_config.dart';

class AppMessenger {
  AppMessenger._();

  static void showSuccess(BuildContext context, String message) {
    DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger showSuccess: $message');
    _showSnackBar(context, message, _SnackBarType.success);
  }

  static void showError(BuildContext context, String message) {
    DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger showError: $message');
    _showSnackBar(context, message, _SnackBarType.error);
  }

  static void showInfo(BuildContext context, String message) {
    DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger showInfo: $message');
    _showSnackBar(context, message, _SnackBarType.info);
  }

  static void _showSnackBar(BuildContext context, String message, _SnackBarType type) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      DebugConfig.warn('AppMessenger: no ScaffoldMessenger available, skipping snackbar: $message');
      return;
    }
    final theme = Theme.of(context);
    final colors = _colorsFor(type, theme);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(colors.icon, color: colors.iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.textColor),
                ),
              ),
            ],
          ),
          backgroundColor: colors.bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: colors.actionColor,
            onPressed: () {},
          ),
        ),
      );
  }

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger showConfirmDialog: $title ($message)');
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: theme.textTheme.titleMedium),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    IconData? icon,
    String dismissLabel = 'OK',
  }) async {
    DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger showInfoDialog: $title');
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: icon != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(title, style: theme.textTheme.titleMedium)),
              ])
            : Text(title, style: theme.textTheme.titleMedium),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(dismissLabel),
          ),
        ],
      ),
    );
  }

  static void showLoading(BuildContext context, {String? message}) {
    DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger showLoading: ${message ?? "no message"}');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    DebugConfig.log(DebugConfig.uiInteraction, 'AppMessenger hideLoading');
    Navigator.of(context, rootNavigator: true).pop();
  }
}

enum _SnackBarType { success, error, info }

class _SnackBarColors {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;
  final Color actionColor;

  const _SnackBarColors({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.textColor,
    required this.actionColor,
  });
}

_SnackBarColors _colorsFor(_SnackBarType type, ThemeData theme) {
  switch (type) {
    case _SnackBarType.success:
      return _SnackBarColors(
        icon: Icons.check_circle,
        iconColor: const Color(0xFF4CAF50),
        bgColor: const Color(0xFF1B5E20),
        textColor: Colors.white,
        actionColor: const Color(0xFF81C784),
      );
    case _SnackBarType.error:
      return _SnackBarColors(
        icon: Icons.error,
        iconColor: const Color(0xFFEF5350),
        bgColor: const Color(0xFFB71C1C),
        textColor: Colors.white,
        actionColor: const Color(0xFFEF9A9A),
      );
    case _SnackBarType.info:
      return _SnackBarColors(
        icon: Icons.info_outline,
        iconColor: const Color(0xFF42A5F5),
        bgColor: const Color(0xFF0D47A1),
        textColor: Colors.white,
        actionColor: const Color(0xFF90CAF9),
      );
  }
}
