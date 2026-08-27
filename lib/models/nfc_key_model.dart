class NfcKey {
  final String id;
  final int userId;
  final int? createdByAdminId;
  final String tagId;
  final String name;
  final bool isActive;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  const NfcKey({
    required this.id,
    required this.userId,
    this.createdByAdminId,
    required this.tagId,
    required this.name,
    required this.isActive,
    this.lastUsedAt,
    this.createdAt,
    this.revokedAt,
  });

  factory NfcKey.fromJson(Map<String, dynamic> json) {
    return NfcKey(
      id: json['id']?.toString() ?? '',
      userId: _readInt(json['userId']) ?? 0,
      createdByAdminId: _readInt(json['createdByAdminId']),
      tagId: json['tagId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: _readBool(json['isActive']),
      lastUsedAt: _readDate(json['lastUsedAt']),
      createdAt: _readDate(json['createdAt']),
      revokedAt: _readDate(json['revokedAt']),
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

  static DateTime? _readDate(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

class NfcKeyCreateResult {
  final NfcKey key;
  final String ndefUri;

  const NfcKeyCreateResult({
    required this.key,
    required this.ndefUri,
  });

  factory NfcKeyCreateResult.fromJson(Map<String, dynamic> json) {
    return NfcKeyCreateResult(
      key: NfcKey.fromJson(json),
      ndefUri: json['ndefUri']?.toString() ?? '',
    );
  }
}
