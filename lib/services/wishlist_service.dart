import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class WishlistShareState {
  final bool active;
  final String? url;
  const WishlistShareState({required this.active, this.url});
}

class WishlistService {
  Future<dynamic> json(String path, String token,
      {String method = 'GET', Map<String, dynamic>? body}) async {
    final client = http.Client();
    try {
      final req = http.Request(method, Uri.parse('$apiBaseUrl$path'))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Content-Type'] = 'application/json';
      if (body != null) req.body = jsonEncode(body);
      final response = await client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(const Duration(minutes: 2));
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data is Map
            ? data['error'] ?? 'wishlist_unavailable'
            : 'wishlist_unavailable');
      }
      return data;
    } finally {
      client.close();
    }
  }

  static String linkToken(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        !{'s-notes.ru', Uri.parse(apiBaseUrl).host}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'w' ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(uri.pathSegments.last)) {
      throw const FormatException('wishlist_invalid_url');
    }
    return uri.pathSegments.last;
  }

  Future<WishlistShareState> request(String id, String token,
      {String method = 'GET', bool rotate = false}) async {
    final client = http.Client();
    try {
      final req = http.Request(
          method,
          Uri.parse(
              '$apiBaseUrl/api/notes/${Uri.encodeComponent(id)}/wishlist/share${rotate ? '/rotate' : ''}'))
        ..headers['Authorization'] = 'Bearer $token';
      final response = await http.Response.fromStream(await client.send(req))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode == 204) {
        return const WishlistShareState(active: false);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Sharing unavailable');
      }
      return WishlistShareState(
          active: data['active'] == true, url: data['url'] as String?);
    } finally {
      client.close();
    }
  }
}
