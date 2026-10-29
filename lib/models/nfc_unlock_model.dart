class NfcUnlockPayload {
  final String tagId;
  final String secret;

  const NfcUnlockPayload({
    required this.tagId,
    required this.secret,
  });
}

class NfcUnlockResult {
  final String hiddenAccessToken;
  final int expiresInSeconds;
  final String keyId;
  final String name;

  const NfcUnlockResult({
    required this.hiddenAccessToken,
    required this.expiresInSeconds,
    required this.keyId,
    required this.name,
  });

  factory NfcUnlockResult.fromJson(Map<String, dynamic> json) {
    return NfcUnlockResult(
      hiddenAccessToken: json['hiddenAccessToken']?.toString() ?? '',
      expiresInSeconds: _readInt(json['expiresInSeconds']) ?? 0,
      keyId: json['keyId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
