import 'package:flutter/material.dart';

class Note {
  final String id;
  final String title;
  final String body;
  final String? imagePath;
  final List<String> photoPaths;
  final String? voicePath;
  final bool isVoice;
  final bool isVideo;
  final Color color;
  final bool isPending;
  final bool isProtected;
  final String? protectionPassword;

  bool get hasProtection =>
      isProtected ||
      (protectionPassword != null && protectionPassword!.isNotEmpty);

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.imagePath,
    this.photoPaths = const [],
    this.voicePath,
    this.isVoice = false,
    this.isVideo = false,
    this.color = Colors.white,
    this.isPending = false,
    this.isProtected = false,
    this.protectionPassword,
  });

  Note copyWith({
    String? id,
    String? title,
    String? body,
    String? imagePath,
    List<String>? photoPaths,
    String? voicePath,
    bool? isVoice,
    bool? isVideo,
    Color? color,
    bool? isPending,
    bool? isProtected,
    String? protectionPassword,
    bool clearImagePath = false,
    bool clearVoicePath = false,
    bool clearProtectionPassword = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      photoPaths: photoPaths ?? this.photoPaths,
      voicePath: clearVoicePath ? null : (voicePath ?? this.voicePath),
      isVoice: isVoice ?? this.isVoice,
      isVideo: isVideo ?? this.isVideo,
      color: color ?? this.color,
      isPending: isPending ?? this.isPending,
      isProtected: isProtected ?? this.isProtected,
      protectionPassword: clearProtectionPassword
          ? null
          : (protectionPassword ?? this.protectionPassword),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'imagePath': imagePath,
    'photoPaths': photoPaths,
    'voicePath': voicePath,
    'isVoice': isVoice,
    'isVideo': isVideo,
    'color': color.value,
    'isPending': isPending,
    'isProtected': isProtected,
    'protectionPassword': protectionPassword,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    imagePath: json['imagePath'] as String?,
    photoPaths: _readStringList(json['photoPaths']),
    voicePath: json['voicePath'] as String?,
    isVoice: json['isVoice'] as bool? ?? false,
    isVideo: json['isVideo'] as bool? ?? false,
    color: Color(json['color'] as int? ?? 0xFFFFFFFF),
    isPending: json['isPending'] as bool? ?? false,
    isProtected: _readBool(json['isProtected']),
    protectionPassword: json['protectionPassword'] as String?,
  );

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  static List<String> _readStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
