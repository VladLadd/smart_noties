import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Stroke data adapted from Hershey Text JS, Script 1-stroke (alt).
// https://github.com/techninja/hersheytextjs (MIT; assets/licenses/hersheytext.txt).
const _glyphs = <String, (double, List<List<double>>)>{
  'a': (
    16.8,
    [
      [
        9,
        16,
        8,
        14,
        6,
        13,
        4,
        13,
        2,
        14,
        1,
        15,
        0,
        17,
        0,
        19,
        1,
        21,
        3,
        22,
        5,
        22,
        7,
        21,
        8,
        19,
        10,
        13,
        9,
        18,
        9,
        21,
        10,
        22,
        11,
        22,
        13,
        21,
        14,
        20,
        16,
        17
      ]
    ]
  ),
  'e': (
    10.08,
    [
      [
        1,
        20,
        3,
        19,
        4,
        18,
        5,
        16,
        5,
        14,
        4,
        13,
        3,
        13,
        1,
        14,
        0,
        16,
        0,
        19,
        1,
        21,
        3,
        22,
        5,
        22,
        7,
        21,
        8,
        20,
        10,
        17
      ]
    ]
  ),
  'm': (
    20.16,
    [
      [0, 17, 2, 14, 4, 13, 5, 14, 5, 15, 4, 19, 3, 22],
      [4, 19, 5, 17, 7, 14, 9, 13, 11, 13, 12, 14, 12, 15, 11, 19, 10, 22],
      [
        11,
        19,
        12,
        17,
        14,
        14,
        16,
        13,
        18,
        13,
        19,
        14,
        19,
        16,
        18,
        19,
        18,
        21,
        19,
        22,
        20,
        22,
        22,
        21,
        23,
        20,
        25,
        17
      ]
    ]
  ),
  'n': (
    16.8,
    [
      [0, 17, 2, 14, 4, 13, 5, 14, 5, 15, 4, 19, 3, 22],
      [
        4,
        19,
        5,
        17,
        7,
        14,
        9,
        13,
        11,
        13,
        12,
        14,
        12,
        16,
        11,
        19,
        11,
        21,
        12,
        22,
        13,
        22,
        15,
        21,
        16,
        20,
        18,
        17
      ]
    ]
  ),
  'o': (
    13.44,
    [
      [
        6,
        13,
        4,
        13,
        2,
        14,
        1,
        15,
        0,
        17,
        0,
        19,
        1,
        21,
        3,
        22,
        5,
        22,
        7,
        21,
        8,
        20,
        9,
        18,
        9,
        16,
        8,
        14,
        6,
        13,
        5,
        14,
        5,
        16,
        6,
        18,
        8,
        19,
        11,
        19,
        13,
        18,
        14,
        17
      ]
    ]
  ),
  'r': (
    13.44,
    [
      [
        0,
        17,
        2,
        14,
        3,
        12,
        3,
        14,
        6,
        14,
        7,
        15,
        7,
        17,
        6,
        20,
        6,
        21,
        7,
        22,
        8,
        22,
        10,
        21,
        11,
        20,
        13,
        17
      ]
    ]
  ),
  's': (
    11.76,
    [
      [0, 17, 2, 14, 3, 12, 3, 14, 5, 17, 6, 19, 6, 21, 4, 22],
      [0, 21, 2, 22, 6, 22, 8, 21, 9, 20, 11, 17]
    ]
  ),
  't': (
    10.08,
    [
      [0, 17, 2, 14, 4, 10],
      [7, 1, 1, 19, 1, 21, 2, 22, 4, 22, 6, 21, 7, 20, 9, 17],
      [1, 9, 8, 9]
    ]
  ),
};

class HandwrittenWordmark extends StatelessWidget {
  final double progress;
  final Color startColor;
  final Color endColor;
  const HandwrittenWordmark(
      {super.key,
      required this.progress,
      required this.startColor,
      required this.endColor});

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'smart notes',
      image: true,
      child: AspectRatio(
          aspectRatio: 5.3,
          child: CustomPaint(
            painter: _HandwritingPainter(progress, startColor, endColor),
          )));
}

class _HandwritingPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  static final _layout = _makeStrokes();
  static final _strokes = _layout.$1;
  static final _metrics =
      _strokes.expand((path) => path.computeMetrics()).toList();
  static final _totalLength =
      _metrics.fold<double>(0, (sum, metric) => sum + metric.length);
  static final _width = _layout.$2;
  static const _strokeWidth = 2.15;
  static const _letterGap = 3.8;
  _HandwritingPainter(this.progress, this.startColor, this.endColor);

  static (List<Path>, double) _makeStrokes() {
    final paths = <Path>[];
    var x = 2.0;
    for (final letter in 'smart notes'.split('')) {
      if (letter == ' ') {
        x += 11;
        continue;
      }
      final glyph = _glyphs[letter]!;
      final letterPaths = <Path>[];
      for (final stroke in glyph.$2) {
        final points = <Offset>[];
        for (var i = 0; i < stroke.length; i += 2) {
          points.add(Offset(stroke[i], stroke[i + 1]));
        }
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        // Сглаживаем штрихи, сохраняя порядок движения пера и отрывы от бумаги.
        for (var i = 0; i < points.length - 1; i++) {
          final before = points[i == 0 ? i : i - 1];
          final current = points[i];
          final next = points[i + 1];
          final after = points[i + 2 < points.length ? i + 2 : i + 1];
          final c1 = current + (next - before) / 6;
          final c2 = next - (after - current) / 6;
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, next.dx, next.dy);
        }
        letterPaths.add(path);
      }
      // Шаг задаётся фактическими границами буквы, а не шириной шрифта:
      // широкие m/n и выходные штрихи больше не пересекают соседние буквы.
      final bounds = letterPaths
          .map((path) => path.getBounds())
          .reduce((a, b) => a.expandToInclude(b));
      for (final path in letterPaths) {
        paths.add(path.shift(Offset(x - bounds.left, 0)));
      }
      x += bounds.width + _letterGap;
    }
    return (paths, x - _letterGap + 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _width;
    canvas.save();
    canvas.translate(0, (size.height - 24 * scale) / 2);
    canvas.scale(scale);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
          const Offset(0, 0), Offset(_width, 24), [startColor, endColor]);
    var remaining = _totalLength * progress.clamp(0.0, 1.0);
    for (final metric in _metrics) {
      if (remaining <= 0) break;
      canvas.drawPath(
          metric.extractPath(0, remaining.clamp(0, metric.length).toDouble()),
          paint);
      remaining -= metric.length;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HandwritingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      startColor != oldDelegate.startColor ||
      endColor != oldDelegate.endColor;
}
