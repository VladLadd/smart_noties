import 'dart:convert';

import 'package:flutter/material.dart';

enum DrawingTool {
  pen,
  eraser;

  String get jsonValue {
    switch (this) {
      case DrawingTool.pen:
        return 'pen';
      case DrawingTool.eraser:
        return 'eraser';
    }
  }

  static DrawingTool fromJson(Object? value) {
    if (value == 'eraser') return DrawingTool.eraser;
    return DrawingTool.pen;
  }
}

class NoteDrawing {
  final int version;
  final double canvasAspectRatio;
  final List<DrawingStroke> strokes;

  const NoteDrawing({
    this.version = 1,
    this.canvasAspectRatio = 1,
    this.strokes = const [],
  });

  factory NoteDrawing.empty() => const NoteDrawing();

  bool get hasContent => strokes.isNotEmpty;

  NoteDrawing copyWith({
    int? version,
    double? canvasAspectRatio,
    List<DrawingStroke>? strokes,
  }) {
    return NoteDrawing(
      version: version ?? this.version,
      canvasAspectRatio: canvasAspectRatio ?? this.canvasAspectRatio,
      strokes: strokes ?? this.strokes,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'canvasAspectRatio': canvasAspectRatio,
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  static NoteDrawing decode(String? source) {
    final raw = source?.trim() ?? '';
    if (raw.isEmpty) return NoteDrawing.empty();

    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return NoteDrawing.empty();
      return NoteDrawing.fromJson(json);
    } catch (_) {
      return NoteDrawing.empty();
    }
  }

  factory NoteDrawing.fromJson(Map<String, dynamic> json) {
    final rawStrokes = json['strokes'];
    return NoteDrawing(
      version: _readInt(json['version'], fallback: 1),
      canvasAspectRatio: _readDouble(json['canvasAspectRatio'], fallback: 1),
      strokes: rawStrokes is List
          ? rawStrokes
              .whereType<Map<String, dynamic>>()
              .map(DrawingStroke.fromJson)
              .where((stroke) => stroke.points.length >= 2)
              .toList()
          : const [],
    );
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static double _readDouble(Object? value, {required double fallback}) {
    if (value is num && value.isFinite) return value.toDouble();
    return fallback;
  }
}

class DrawingStroke {
  final DrawingTool tool;
  final Color color;
  final double width;
  final List<DrawingPoint> points;

  const DrawingStroke({
    this.tool = DrawingTool.pen,
    required this.color,
    required this.width,
    required this.points,
  });

  DrawingStroke addPoint(DrawingPoint point) {
    return DrawingStroke(
      tool: tool,
      color: color,
      width: width,
      points: [...points, point],
    );
  }

  Map<String, dynamic> toJson() => {
        'tool': tool.jsonValue,
        'color': color.toARGB32(),
        'width': width,
        'points': points.map((point) => point.toJson()).toList(),
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return DrawingStroke(
      tool: DrawingTool.fromJson(json['tool']),
      color: Color(_readInt(json['color'], fallback: Colors.black.toARGB32())),
      width: _readDouble(json['width'], fallback: 0.012).clamp(0.002, 0.08),
      points: rawPoints is List
          ? rawPoints
              .whereType<Map<String, dynamic>>()
              .map(DrawingPoint.fromJson)
              .toList()
          : const [],
    );
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static double _readDouble(Object? value, {required double fallback}) {
    if (value is num && value.isFinite) return value.toDouble();
    return fallback;
  }
}

class DrawingPoint {
  final double x;
  final double y;

  const DrawingPoint({
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
      };

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      x: _readCoordinate(json['x']),
      y: _readCoordinate(json['y']),
    );
  }

  static double _readCoordinate(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble().clamp(0.0, 1.0);
    }
    return 0;
  }
}
