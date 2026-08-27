class VideoPreview {
  final String provider;
  final String mode;
  final String title;
  final String thumbnailUrl;
  final int durationSeconds;
  final bool canDownload;
  final String reason;
  final String normalizedUrl;
  final Map<String, dynamic> metadata;

  const VideoPreview({
    required this.provider,
    required this.mode,
    required this.title,
    this.thumbnailUrl = '',
    this.durationSeconds = 0,
    this.canDownload = false,
    this.reason = '',
    this.normalizedUrl = '',
    this.metadata = const <String, dynamic>{},
  });

  bool get isLinkOnly => mode == 'link_only';
  bool get isDirectFile => provider == 'direct' && mode == 'file';

  factory VideoPreview.fromJson(Map<String, dynamic> json) {
    return VideoPreview(
      provider: json['provider']?.toString() ?? 'unknown',
      mode: json['mode']?.toString() ?? 'link_only',
      title: json['title']?.toString() ?? 'Видео',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      durationSeconds: _readInt(json['durationSeconds']) ?? 0,
      canDownload: _readBool(json['canDownload']),
      reason: json['reason']?.toString() ?? '',
      normalizedUrl: json['normalizedUrl']?.toString() ?? '',
      metadata: _readMap(json['metadata']),
    );
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
