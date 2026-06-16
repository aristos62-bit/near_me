import 'package:flutter/material.dart';
import '../../core/debug/debug_config.dart';
import '../../core/theme/app_colors.dart';

class ChipSelector extends StatelessWidget {
  final List<String> options;
  final String? selectedValue;
  final void Function(String?) onSelected;
  final Map<String, String>? labels;
  final double chipBorderRadius;

  const ChipSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.labels,
    this.chipBorderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 4, children: options.map((o) {
      final s = selectedValue == o;
      return ChoiceChip(
        label: Text(labels?[o] ?? o),
        selected: s,
        onSelected: (v) {
          DebugConfig.log(DebugConfig.uiInteraction, 'ChipSelector: $o selected=$v');
          onSelected(v ? o : null);
        },
        selectedColor: AppColors.primary.withAlpha(30),
        labelStyle: TextStyle(
          color: s ? AppColors.primary : null,
          fontWeight: s ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(chipBorderRadius)),
      );
    }).toList());
  }
}
