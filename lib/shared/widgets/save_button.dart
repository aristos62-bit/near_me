import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  final bool isSaving;
  final String label;
  final String savingLabel;
  final VoidCallback? onPressed;
  final IconData icon;

  const SaveButton({
    super.key,
    required this.isSaving,
    required this.label,
    required this.onPressed,
    this.savingLabel = 'Αποθήκευση...',
    this.icon = Icons.check_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.icon(
      onPressed: isSaving ? null : onPressed,
      icon: isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 20),
      label: Text(isSaving ? savingLabel : label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
