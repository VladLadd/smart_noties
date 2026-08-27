import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Открывает диалог выбора произвольного цвета (HSV-пикер) и возвращает
/// выбранный цвет, либо null, если пользователь отменил.
Future<Color?> showCustomColorPicker(
  BuildContext context, {
  required Color initialColor,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initialColor: initialColor),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexController;
  final FocusNode _hexFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _hex);
  }

  @override
  void dispose() {
    _hexController.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  String get _hex =>
      '#${_color.value.toRadixString(16).substring(2).toUpperCase()}';

  // Обновление из слайдеров: правим цвет и синхронизируем поле HEX,
  // но не перезаписываем текст, пока пользователь сам печатает в нём.
  void _updateHsv(HSVColor hsv) {
    setState(() => _hsv = hsv);
    if (!_hexFocus.hasFocus) {
      _hexController.value = TextEditingValue(
        text: _hex,
        selection: TextSelection.collapsed(offset: _hex.length),
      );
    }
  }

  // Разбор пользовательского ввода: поддержка форматов RGB и RRGGBB, с '#' и без.
  Color? _parseHex(String input) {
    var s = input.trim().replaceAll('#', '').toUpperCase();
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  void _onHexChanged(String input) {
    final color = _parseHex(input);
    if (color != null) {
      setState(() => _hsv = HSVColor.fromColor(color));
    }
  }

  @override
  Widget build(BuildContext context) {
    const double width = 260;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Выберите цвет'),
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Квадрат насыщенность (X) / яркость (Y)
            _SaturationValueArea(
              hsv: _hsv,
              size: const Size(width, 170),
              onChanged: (s, v) =>
                  _updateHsv(_hsv.withSaturation(s).withValue(v)),
            ),
            const SizedBox(height: 16),
            // Слайдер оттенка
            _HueSlider(
              hue: _hsv.hue,
              width: width,
              onChanged: (h) => _updateHsv(_hsv.withHue(h)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    focusNode: _hexFocus,
                    onChanged: _onHexChanged,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9a-fA-F#]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    style: const TextStyle(
                      fontSize: 16,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '#RRGGBB',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Выбрать'),
        ),
      ],
    );
  }
}

/// Квадрат выбора насыщенности (по горизонтали) и яркости (по вертикали).
class _SaturationValueArea extends StatelessWidget {
  final HSVColor hsv;
  final Size size;
  final void Function(double saturation, double value) onChanged;

  const _SaturationValueArea({
    required this.hsv,
    required this.size,
    required this.onChanged,
  });

  void _handle(Offset localPosition) {
    final s = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - localPosition.dy / size.height).clamp(0.0, 1.0);
    onChanged(s, v);
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    final selectorX = hsv.saturation * size.width;
    final selectorY = (1 - hsv.value) * size.height;

    return GestureDetector(
      onPanDown: (d) => _handle(d.localPosition),
      onPanUpdate: (d) => _handle(d.localPosition),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              // белый -> чистый оттенок (насыщенность)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, hueColor],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              // прозрачный -> чёрный (яркость)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              // указатель текущего выбора
              Positioned(
                left: selectorX - 8,
                top: selectorY - 8,
                child: _Thumb(color: hsv.toColor()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Горизонтальный слайдер оттенка (0..360).
class _HueSlider extends StatelessWidget {
  final double hue;
  final double width;
  final ValueChanged<double> onChanged;

  const _HueSlider({
    required this.hue,
    required this.width,
    required this.onChanged,
  });

  static const List<Color> _spectrum = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  void _handle(Offset localPosition) {
    onChanged(((localPosition.dx / width).clamp(0.0, 1.0)) * 360);
  }

  @override
  Widget build(BuildContext context) {
    const double height = 24;
    final selectorX = (hue / 360) * width;

    return GestureDetector(
      onPanDown: (d) => _handle(d.localPosition),
      onPanUpdate: (d) => _handle(d.localPosition),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: const LinearGradient(colors: _spectrum),
              ),
            ),
            Positioned(
              left: (selectorX - 8).clamp(0.0, width - 16),
              top: (height - 16) / 2,
              child: _Thumb(color: HSVColor.fromAHSV(1, hue, 1, 1).toColor()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Круглый указатель-«ручка» на пикере.
class _Thumb extends StatelessWidget {
  final Color color;

  const _Thumb({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 2),
        ],
      ),
    );
  }
}
