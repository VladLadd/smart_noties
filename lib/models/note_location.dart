import 'dart:convert';

class NoteLocation {
  final double latitude;
  final double longitude;
  final String label;
  const NoteLocation(
      {required this.latitude, required this.longitude, this.label = ''});

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
  String get coordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  String encode() {
    if (!isValid) throw const FormatException('Некорректные координаты');
    return jsonEncode(
        {'latitude': latitude, 'longitude': longitude, 'label': label});
  }

  static NoteLocation? decode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final location = NoteLocation(
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble(),
          label: json['label'] as String? ?? '');
      return location.isValid ? location : null;
    } catch (_) {
      return null;
    }
  }
}
