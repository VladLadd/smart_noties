import 'package:flutter/material.dart';

class Note {
  final String id;
  final String title;
  final String body;
  final String? imagePath;
  final String? voicePath;
  final bool isVoice;
  final bool isVideo;
  final Color color;
  final bool isPending;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.imagePath,
    this.voicePath,
    this.isVoice = false,
    this.isVideo = false,
    this.color = Colors.white,
    this.isPending = false,
  });

  Note copyWith({
    String? id,
    String? title,
    String? body,
    String? imagePath,
    String? voicePath,
    bool? isVoice,
    bool? isVideo,
    Color? color,
    bool? isPending,
    bool clearImagePath = false,
    bool clearVoicePath = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      voicePath: clearVoicePath ? null : (voicePath ?? this.voicePath),
      isVoice: isVoice ?? this.isVoice,
      isVideo: isVideo ?? this.isVideo,
      color: color ?? this.color,
      isPending: isPending ?? this.isPending,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'imagePath': imagePath,
    'voicePath': voicePath,
    'isVoice': isVoice,
    'isVideo': isVideo,
    'color': color.value,
    'isPending': isPending,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    imagePath: json['imagePath'] as String?,
    voicePath: json['voicePath'] as String?,
    isVoice: json['isVoice'] as bool? ?? false,
    isVideo: json['isVideo'] as bool? ?? false,
    color: Color(json['color'] as int? ?? 0xFFFFFFFF),
    isPending: json['isPending'] as bool? ?? false,
  );
}
