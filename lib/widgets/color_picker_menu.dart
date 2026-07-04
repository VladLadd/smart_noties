import 'package:flutter/material.dart';
import '../data/note_data.dart';
import 'color_picker_dialog.dart';

class ColorPickerMenu extends StatefulWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerMenu({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerMenu> createState() => _ColorPickerMenuState();
}

class _ColorPickerMenuState extends State<ColorPickerMenu> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggleOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlay();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _closeOverlay();
    }
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // Цвет считается кастомным, если его нет в стандартной палитре.
  bool get _isCustomSelected => !noteColors.contains(widget.selectedColor);

  Future<void> _openCustomPicker() async {
    _closeOverlay();
    final picked = await showCustomColorPicker(
      context,
      initialColor: widget.selectedColor,
    );
    if (picked != null) {
      widget.onColorSelected(picked);
    }
  }

  OverlayEntry _createOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;

    return OverlayEntry(
      builder: (context) => Positioned(
        top: renderBox.localToGlobal(Offset.zero).dy + renderBox.size.height + 5,
        left: renderBox.localToGlobal(Offset.zero).dx,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-3, 50),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...noteColors.map((color) {
                    final isSelected = widget.selectedColor == color;
                    return _MenuItem(
                      isSelected: isSelected,
                      color: color,
                      onTap: () {
                        widget.onColorSelected(color);
                        _closeOverlay();
                      },
                    );
                  }),
                  // Пункт «мультиколор» — открывает color picker.
                  _MenuItem(
                    isSelected: _isCustomSelected,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                    onTap: _openCustomPicker,
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleOverlay,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: widget.selectedColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Круглый пункт меню палитры (стандартный цвет или «мультиколор»).
class _MenuItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;
  final Widget? child;

  const _MenuItem({
    required this.isSelected,
    required this.onTap,
    this.color,
    this.gradient,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
