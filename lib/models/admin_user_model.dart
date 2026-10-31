class AdminUser {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final int nfcKeysCount;
  final bool isBlocked;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.nfcKeysCount,
    required this.isBlocked,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: _readInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      nfcKeysCount: _readInt(json['nfcKeysCount']) ?? 0,
      isBlocked: json['isBlocked'] == true,
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
