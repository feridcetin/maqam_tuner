import 'package:flutter/material.dart';

import '../l10n/tx.dart';
import 'theme.dart';

/// A row of choice chips that wraps onto several lines on narrow screens.
/// (A SegmentedButton squeezes its labels and breaks them across lines on
/// small devices.)
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, label) in options)
          ChoiceChip(
            label: Tx(label),
            selected: v == value,
            showCheckmark: false,
            onSelected: (_) => onChanged(v),
            selectedColor: Palette.brass.withAlpha(70),
            backgroundColor: Palette.panel,
            side: BorderSide(color: v == value ? Palette.brass : Palette.line),
          ),
      ],
    );
  }
}
