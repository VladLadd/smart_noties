// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'api_config.dart';

Future<void> openAttachment(String path,
    {required String name, String? token, String? password}) async {
  if (!path.startsWith('/api/file/')) {
    throw Exception('Недопустимый адрес вложения');
  }
  final response = await http.get(Uri.parse('$apiBaseUrl$path'), headers: {
    'Authorization': 'Bearer $token',
    if (password != null) 'X-Media-Password': password,
  }).timeout(const Duration(minutes: 5));
  if (response.statusCode != 200) {
    throw Exception('Не удалось скачать вложение');
  }
  final url = html.Url.createObjectUrlFromBlob(html.Blob([response.bodyBytes]));
  final anchor = html.AnchorElement(href: url)..download = name;
  anchor.click();
  Future.delayed(
      const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
}
