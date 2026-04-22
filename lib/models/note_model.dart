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

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.imagePath,
    this.voicePath,
    this.isVoice = false,
    this.isVideo = false,
    this.color = Colors.white,
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
    );
  }
}
