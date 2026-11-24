import 'dart:convert';
import 'dart:math';

enum NoteType { note, wishlist }

class WishlistItem {
  final String id, title, description, productUrl, imagePath, currency;
  final int? priceMinor;
  const WishlistItem(
      {required this.id,
      required this.title,
      this.description = '',
      this.productUrl = '',
      this.imagePath = '',
      this.priceMinor,
      this.currency = 'RUB'});
  static String newId() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  WishlistItem withImage(String path) => WishlistItem(
      id: id,
      title: title,
      description: description,
      productUrl: productUrl,
      imagePath: path,
      priceMinor: priceMinor,
      currency: currency);
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'productUrl': productUrl,
        'imagePath': imagePath,
        if (priceMinor != null) 'priceMinor': priceMinor,
        if (priceMinor != null) 'currency': currency
      };
  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      productUrl: json['productUrl'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      priceMinor: json['priceMinor'] as int?,
      currency: json['currency'] as String? ?? 'RUB');
}

class WishlistData {
  final List<WishlistItem> items;
  const WishlistData({this.items = const []});
  String encode() => jsonEncode(
      {'version': 1, 'items': items.map((i) => i.toJson()).toList()});
  static WishlistData decode(String? raw) {
    if (raw == null || raw.isEmpty) return const WishlistData();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['items'] is! List ||
        (data['items'] as List).length > 100) {
      throw const FormatException('Неподдерживаемая версия вишлиста');
    }
    return WishlistData(
        items: (data['items'] as List)
            .map((i) => WishlistItem.fromJson(Map<String, dynamic>.from(i)))
            .toList());
  }

  Future<WishlistData> mapImages(
      Future<String> Function(String) transform) async {
    final result = <WishlistItem>[];
    for (final item in items) {
      result.add(item.imagePath.isEmpty
          ? item
          : item.withImage(await transform(item.imagePath)));
    }
    return WishlistData(items: result);
  }

  Iterable<String> get imagePaths =>
      items.map((i) => i.imagePath).where((p) => p.isNotEmpty);
}
