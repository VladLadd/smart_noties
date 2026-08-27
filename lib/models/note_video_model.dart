class NoteVideo {
  final String id;
  final String? noteId;
  final int? userId;
  final String provider;
  final String sourceUrl;
  final String? storagePath;
  final String? thumbnailPath;
  final String title;
  final String status;
  final int progress;
  final String error;
  final Map<String, dynamic> metadata;
  final bool isProtected;

  const NoteVideo({
    required this.id,
    this.noteId,
    this.userId,
    this.provider = 'unknown',
    this.sourceUrl = '',
    this.storagePath,
    this.thumbnailPath,
    this.title = '',
    this.status = 'ready',
    this.progress = 0,
    this.error = '',
    this.metadata = const <String, dynamic>{},
    this.isProtected = false,
  });

  bool get hasStoredFile => storagePath != null && storagePath!.isNotEmpty;
  bool get isLinkOnly => status == 'link_only' || !hasStoredFile;

  NoteVideo copyWith({
    String? id,
    String? noteId,
    int? userId,
    String? provider,
    String? sourceUrl,
    String? storagePath,
    String? thumbnailPath,
    String? title,
    String? status,
    int? progress,
    String? error,
    Map<String, dynamic>? metadata,
    bool? isProtected,
    bool clearNoteId = false,
    bool clearStoragePath = false,
    bool clearThumbnailPath = false,
  }) {
    return NoteVideo(
      id: id ?? this.id,
      noteId: clearNoteId ? null : (noteId ?? this.noteId),
      userId: userId ?? this.userId,
      provider: provider ?? this.provider,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      storagePath: clearStoragePath ? null : (storagePath ?? this.storagePath),
      thumbnailPath:
          clearThumbnailPath ? null : (thumbnailPath ?? this.thumbnailPath),
      title: title ?? this.title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
      isProtected: isProtected ?? this.isProtected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'userId': userId,
        'provider': provider,
        'sourceUrl': sourceUrl,
        'storagePath': storagePath,
        'thumbnailPath': thumbnailPath,
        'title': title,
        'status': status,
        'progress': progress,
        'error': error,
        'metadata': metadata,
        'isProtected': isProtected,
      };

  factory NoteVideo.fromJson(Map<String, dynamic> json) {
    return NoteVideo(
      id: json['id']?.toString() ?? '',
      noteId: _readNullableString(json['noteId']),
      userId: _readInt(json['userId']),
      provider: json['provider']?.toString() ?? 'unknown',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      storagePath: _readNullableString(json['storagePath']),
      thumbnailPath: _readNullableString(json['thumbnailPath']),
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ready',
      progress: _readInt(json['progress']) ?? 0,
      error: json['error']?.toString() ?? '',
      metadata: _readMap(json['metadata']),
      isProtected: _readBool(json['isProtected']),
    );
  }

  static List<NoteVideo> listFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .map(NoteVideo.fromJson)
        .toList();
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }
}
