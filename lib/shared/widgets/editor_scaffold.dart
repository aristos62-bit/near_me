import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/debug/debug_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/responsive_utils.dart';
import '../../core/utils/app_messenger.dart';
import 'app_state_widget.dart';

class EditorScaffold extends StatelessWidget {
  final String title;
  final String screenName;
  final ValueGetter<bool> isDirty;
  final ValueGetter<bool> isSaving;
  final bool isLoading;
  final Future<void> Function() onSave;
  final Widget body;
  final Widget? loadingBody;

  const EditorScaffold({
    super.key,
    required this.title,
    required this.screenName,
    required this.isDirty,
    required this.isSaving,
    required this.isLoading,
    required this.onSave,
    required this.body,
    this.loadingBody,
  });

  static Future<void> _onBack(
    BuildContext context,
    ValueGetter<bool> isDirty,
    ValueGetter<bool> isSaving,
    Future<void> Function() onSave,
    String screenName,
  ) async {
    final dirty = isDirty();
    final saving = isSaving();
    DebugConfig.log(
      DebugConfig.uiInteraction,
      '$screenName onBack, dirty=$dirty, saving=$saving',
    );
    if (saving) return;
    if (!dirty) {
      if (context.mounted) context.pop();
      return;
    }
    final g = L10n.isGreek(context);
    final save = await AppMessenger.showConfirmDialog(
      context,
      title: g ? 'Αποθήκευση αλλαγών;' : 'Save changes?',
      message: g
          ? 'Έχεις μη αποθηκευμένες αλλαγές. Θες να αποθηκευτούν;'
          : 'You have unsaved changes. Save them?',
      confirmLabel: g ? 'Αποθήκευση' : 'Save',
      cancelLabel: g ? 'Απόρριψη' : 'Discard',
    );
    if (save == true) {
      await onSave();
    } else if (save == false && context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _onBack(context, isDirty, isSaving, onSave, screenName);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                _onBack(context, isDirty, isSaving, onSave, screenName),
          ),
          title: Text(title),
        ),
        body: isLoading
            ? (loadingBody ?? const LoadingView())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final w = ResponsiveUtils.resolveWidth(context, constraints);
                  return Center(
                    child: SizedBox(
                      width: ResponsiveUtils.maxContentWidthFromWidth(w),
                      child: body,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
