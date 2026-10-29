import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/note_drawing_model.dart';
import '../providers/locale_provider.dart';

class NoteDrawingToolbar extends StatelessWidget {
  final DrawingTool selectedTool;
  final Color selectedColor;
  final double selectedWidth;
  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final ValueChanged<DrawingTool> onToolSelected;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onClose;

  const NoteDrawingToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.selectedWidth,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.onToolSelected,
    required this.onColorSelected,
    required this.onWidthChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onClose,
  });

  static const _colors = <Color>[
    Colors.black,
    Colors.white,
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFFB300),
    Color(0xFF8E24AA),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = scheme.surface.withValues(alpha: isDark ? 0.26 : 0.38);
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.34);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(top: BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
                blurRadius: 26,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _ToolButton(
                          icon: Icons.edit,
                          tooltip: strings.pen,
                          selected: selectedTool == DrawingTool.pen,
                          onPressed: () => onToolSelected(DrawingTool.pen),
                        ),
                        const SizedBox(width: 6),
                        _ToolButton(
                          icon: Icons.auto_fix_off,
                          tooltip: strings.eraser,
                          selected: selectedTool == DrawingTool.eraser,
                          onPressed: () => onToolSelected(DrawingTool.eraser),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _colors
                                  .map(
                                    (color) => _ColorSwatch(
                                      color: color,
                                      selected: color.toARGB32() ==
                                          selectedColor.toARGB32(),
                                      onTap: () => onColorSelected(color),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: strings.undo,
                          icon: const Icon(Icons.undo),
                          onPressed: canUndo ? onUndo : null,
                        ),
                        IconButton(
                          tooltip: strings.redo,
                          icon: const Icon(Icons.redo),
                          onPressed: canRedo ? onRedo : null,
                        ),
                        IconButton(
                          tooltip: strings.clearDrawing,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          onPressed: canClear ? onClear : null,
                        ),
                        IconButton(
                          tooltip: strings.closeDrawing,
                          icon: const Icon(Icons.close),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.line_weight,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Slider(
                            min: 0.004,
                            max: 0.04,
                            value: selectedWidth.clamp(0.004, 0.04),
                            onChanged: onWidthChanged,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      isSelected: selected,
      selectedIcon: Icon(icon),
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor:
            selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      ),
      onPressed: onPressed,
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color:
                  selected ? borderColor : borderColor.withValues(alpha: 0.2),
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
