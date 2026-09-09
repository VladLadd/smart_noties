import 'package:flutter/material.dart';

import 'note_video_model.dart';

class Note {
  final String id;
  final String title;
  final String body;
  final String? drawingData;
  final String? imagePath;
  final List<String> photoPaths;
  final String? voicePath;
  final bool isVoice;
  final bool _isVideo;
  final List<NoteVideo> videos;
  final Color color;
  final bool isPending;
  final bool isProtected;
  final bool isHidden;
  final String? hiddenKeyId;
  final String? protectionPassword;

  bool get isVideo => _isVideo || videos.isNotEmpty;

  bool get hasProtection =>
      isProtected ||
      (protectionPassword != null && protectionPassword!.isNotEmpty);

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.drawingData,
    this.imagePath,
    this.photoPaths = const [],
    this.voicePath,
    this.isVoice = false,
    bool isVideo = false,
    this.videos = const [],
    this.color = Colors.white,
    this.isPending = false,
    this.isProtected = false,
    this.isHidden = false,
    this.hiddenKeyId,
    this.protectionPassword,
  }) : _isVideo = isVideo;

  Note copyWith({
    String? id,
    String? title,
    String? body,
    String? drawingData,
    String? imagePath,
    List<String>? photoPaths,
    String? voicePath,
    bool? isVoice,
    bool? isVideo,
    List<NoteVideo>? videos,
    Color? color,
    bool? isPending,
    bool? isProtected,
    bool? isHidden,
    String? hiddenKeyId,
    String? protectionPassword,
    bool clearImagePath = false,
    bool clearDrawingData = false,
    bool clearVoicePath = false,
    bool clearHiddenKeyId = false,
    bool clearProtectionPassword = false,
  }) {
    final nextVideos = videos ?? this.videos;
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      drawingData: clearDrawingData ? null : (drawingData ?? this.drawingData),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      photoPaths: photoPaths ?? this.photoPaths,
      voicePath: clearVoicePath ? null : (voicePath ?? this.voicePath),
      isVoice: isVoice ?? this.isVoice,
      isVideo: isVideo ?? (videos != null ? nextVideos.isNotEmpty : _isVideo),
      videos: nextVideos,
      color: color ?? this.color,
      isPending: isPending ?? this.isPending,
      isProtected: isProtected ?? this.isProtected,
      isHidden: isHidden ?? this.isHidden,
      hiddenKeyId: clearHiddenKeyId ? null : (hiddenKeyId ?? this.hiddenKeyId),
      protectionPassword: clearProtectionPassword
          ? null
          : (protectionPassword ?? this.protectionPassword),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'drawingData': drawingData,
        'imagePath': imagePath,
        'photoPaths': photoPaths,
        'voicePath': voicePath,
        'isVoice': isVoice,
        'isVideo': isVideo,
        'videos': videos.map((video) => video.toJson()).toList(),
        'color': color.toARGB32(),
        'isPending': isPending,
        'isProtected': isProtected,
        'isHidden': isHidden,
        'hiddenKeyId': hiddenKeyId,
        'protectionPassword': protectionPassword,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    final videos = NoteVideo.listFromJson(json['videos']);
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      drawingData: _readNullableString(json['drawingData']),
      imagePath: _readNullableString(json['imagePath']),
      photoPaths: _readStringList(json['photoPaths']),
      voicePath: _readNullableString(json['voicePath']),
      isVoice: json['isVoice'] as bool? ?? false,
      isVideo: (json['isVideo'] as bool? ?? false) || videos.isNotEmpty,
      videos: videos,
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
      isPending: json['isPending'] as bool? ?? false,
      isProtected: _readBool(json['isProtected']),
      isHidden: _readBool(json['isHidden']),
      hiddenKeyId: _readNullableString(json['hiddenKeyId']),
      protectionPassword: json['protectionPassword'] as String?,
    );
  }

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

  static String? _readNullableString(Object? value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }
}
