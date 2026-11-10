import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';

class ImageNormalizer {
  final http.Client? client;
  const ImageNormalizer({this.client});

  Future<Uint8List?> normalize(XFile file, {String? token}) async {
    final size = await file.length();
    final head = await file
        .openRead(0, size < 64 ? size : 64)
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    // iOS может оставить расширение HEIC после преобразования данных в JPEG.
    if (head.length >= 3 &&
        head[0] == 255 &&
        head[1] == 216 &&
        head[2] == 255) {
      return null;
    }
    if (head.length >= 4 &&
        head[0] == 137 &&
        head[1] == 80 &&
        head[2] == 78 &&
        head[3] == 71) {
      return null;
    }
    final name = file.name.toLowerCase();
    final header = ascii.decode(head, allowInvalid: true);
    final heic = name.endsWith('.heic') ||
        name.endsWith('.heif') ||
        file.mimeType == 'image/heic' ||
        file.mimeType == 'image/heif' ||
        (header.contains('ftyp') &&
            RegExp('heic|heix|hevc|hevx|heim|heis').hasMatch(header));
    if (!heic) return null;
    if (size > 15 * 1024 * 1024) {
      throw Exception('file too large or invalid form');
    }
    if (token == null || token.isEmpty) throw Exception('unauthorized');
    final request = http.MultipartRequest(
        'POST', Uri.parse('$apiBaseUrl/api/image/normalize'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile('file', file.openRead(), size,
          filename: file.name));
    final activeClient = client ?? http.Client();
    try {
      final response = await http.Response.fromStream(await activeClient
              .send(request)
              .timeout(const Duration(minutes: 2)))
          .timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        String message = 'Не удалось преобразовать HEIC';
        try {
          message = (jsonDecode(response.body) as Map<String, dynamic>)['error']
                  ?.toString() ??
              message;
        } catch (_) {}
        throw Exception(message);
      }
      if (!response.headers['content-type'].toString().startsWith('image/')) {
        throw Exception('Не удалось преобразовать HEIC');
      }
      return response.bodyBytes;
    } finally {
      if (client == null) activeClient.close();
    }
  }
}
