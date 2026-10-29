class NfcTokenRequest {
  final String id;
  final int userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String status;
  final String name;
  final String nfcKeyId;
  final String ndefUri;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final DateTime? consumedAt;
  final DateTime? rejectedAt;

  const NfcTokenRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.status,
    required this.name,
    required this.nfcKeyId,
    required this.ndefUri,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.consumedAt,
    this.rejectedAt,
  });

  factory NfcTokenRequest.fromJson(Map<String, dynamic> json) {
    return NfcTokenRequest(
      id: json['id']?.toString() ?? '',
      userId: _readInt(json['userId']) ?? 0,
      userName: json['userName']?.toString() ?? '',
      userEmail: json['userEmail']?.toString() ?? '',
      userPhone: json['userPhone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      name: json['name']?.toString() ?? '',
      nfcKeyId: json['nfcKeyId']?.toString() ?? '',
      ndefUri: json['ndefUri']?.toString() ?? '',
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
      approvedAt: _readDate(json['approvedAt']),
      consumedAt: _readDate(json['consumedAt']),
      rejectedAt: _readDate(json['rejectedAt']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isConsumed => status == 'consumed';
  bool get isRejected => status == 'rejected';

  String get title => name.isNotEmpty ? name : 'NFC-токен';

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _readDate(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
