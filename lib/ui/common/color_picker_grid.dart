import 'package:flutter/material.dart';
import '../colors.dart';

/// A grid of large, tappable colour swatches used as the fallback avatar
/// colour picker for LINE contacts and phone contacts. Tapping a swatch
/// immediately reports the selection via [onColorSelected].
class ColorPickerGrid extends StatelessWidget {
  final Color? selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerGrid({
    super.key,
    required this.onColorSelected,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      children: avatarColorPalette.map((color) {
        final isSelected = color == selectedColor;
        return Padding(
          padding: const EdgeInsets.all(6),
          child: GestureDetector(
            onTap: () => onColorSelected(color),
            child: CircleAvatar(
              backgroundColor: color,
              radius: 28,
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 28)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
