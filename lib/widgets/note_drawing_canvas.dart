import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/note_drawing_model.dart';

class NoteDrawingCanvas extends StatefulWidget {
  final NoteDrawing drawing;
  final bool readOnly;
  final DrawingTool tool;
  final Color strokeColor;
  final double strokeWidth;
  final ValueChanged<NoteDrawing>? onChanged;
  final VoidCallback? onChangeStart;

  const NoteDrawingCanvas({
    super.key,
    required this.drawing,
    this.readOnly = true,
    this.tool = DrawingTool.pen,
    this.strokeColor = Colors.black,
    this.strokeWidth = 0.012,
    this.onChanged,
    this.onChangeStart,
  });

  @override
  State<NoteDrawingCanvas> createState() => _NoteDrawingCanvasState();
}

class _NoteDrawingCanvasState extends State<NoteDrawingCanvas> {
  late NoteDrawing _liveDrawing;
  bool _drawingGestureActive = false;

  @override
  void initState() {
    super.initState();
    _liveDrawing = widget.drawing;
  }

  @override
  void didUpdateWidget(covariant NoteDrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_drawingGestureActive && oldWidget.drawing != widget.drawing) {
      _liveDrawing = widget.drawing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawing = widget.readOnly ? widget.drawing : _liveDrawing;
    final painter = _NoteDrawingPainter(drawing);
    if (widget.readOnly) {
      return IgnorePointer(
        child: CustomPaint(
          painter: painter,
          size: Size.infinite,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) => _handleStart(details.localPosition, size),
          onPanUpdate: (details) => _handleUpdate(details.localPosition, size),
          onPanEnd: (_) => _handleEnd(),
          onPanCancel: _handleEnd,
          child: CustomPaint(
            painter: painter,
            size: Size.infinite,
          ),
        );
      },
    );
  }

  void _handleStart(Offset localPosition, Size size) {
    final point = _normalize(localPosition, size);
    if (point == null) return;
    _drawingGestureActive = true;
    widget.onChangeStart?.call();

    if (widget.tool == DrawingTool.eraser) {
      _eraseAt(point);
      return;
    }

    final stroke = DrawingStroke(
      tool: DrawingTool.pen,
      color: widget.strokeColor,
      width: widget.strokeWidth,
      points: [point, point],
    );
    _emit(
      _liveDrawing.copyWith(
        canvasAspectRatio: _aspectRatio(size),
        strokes: [..._liveDrawing.strokes, stroke],
      ),
    );
  }

  void _handleUpdate(Offset localPosition, Size size) {
    final point = _normalize(localPosition, size);
    if (point == null) return;

    if (widget.tool == DrawingTool.eraser) {
      _eraseAt(point);
      return;
    }

    if (_liveDrawing.strokes.isEmpty) return;
    final strokes = [..._liveDrawing.strokes];
    final last = strokes.last;
    final previous = last.points.isEmpty ? null : last.points.last;
    if (previous != null && _distance(previous, point) < 0.003) return;
    strokes[strokes.length - 1] = last.addPoint(point);
    _emit(
      _liveDrawing.copyWith(
        canvasAspectRatio: _aspectRatio(size),
        strokes: strokes,
      ),
    );
  }

  void _eraseAt(DrawingPoint point) {
    final radius = math.max(widget.strokeWidth * 2.6, 0.025);
    final nextStrokes = _liveDrawing.strokes
        .where((stroke) => !_strokeTouches(stroke, point, radius))
        .toList();
    if (nextStrokes.length == _liveDrawing.strokes.length) return;
    _emit(_liveDrawing.copyWith(strokes: nextStrokes));
  }

  void _emit(NoteDrawing drawing) {
    setState(() => _liveDrawing = drawing);
    widget.onChanged?.call(drawing);
  }

  void _handleEnd() {
    _drawingGestureActive = false;
  }

  bool _strokeTouches(
    DrawingStroke stroke,
    DrawingPoint point,
    double radius,
  ) {
    for (final candidate in stroke.points) {
      if (_distance(candidate, point) <= radius) return true;
    }
    return false;
  }

  DrawingPoint? _normalize(Offset offset, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    final x = (offset.dx / size.width).clamp(0.0, 1.0);
    final y = (offset.dy / size.height).clamp(0.0, 1.0);
    return DrawingPoint(x: x, y: y);
  }

  double _aspectRatio(Size size) {
    if (size.height <= 0) return 1;
    return size.width / size.height;
  }

  double _distance(DrawingPoint a, DrawingPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _NoteDrawingPainter extends CustomPainter {
  final NoteDrawing drawing;

  const _NoteDrawingPainter(this.drawing);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    for (final stroke in drawing.strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = math.max(stroke.width * size.width, 1.2)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      final path = Path();
      final first = _denormalize(stroke.points.first, size);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < stroke.points.length; i += 1) {
        final point = _denormalize(stroke.points[i], size);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  Offset _denormalize(DrawingPoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }

  @override
  bool shouldRepaint(covariant _NoteDrawingPainter oldDelegate) {
    return oldDelegate.drawing != drawing;
  }
}
