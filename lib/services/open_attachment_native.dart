import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'api_config.dart';

Future<void> openAttachment(String path,
    {required String name, String? token, String? password}) async {
  var local = path;
  if (isRemoteMedia(path)) {
    if (!path.startsWith('/api/file/')) {
      throw Exception('Недопустимый адрес вложения');
    }
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse('$apiBaseUrl$path'))
        ..headers['Authorization'] = 'Bearer $token';
      if (password != null) request.headers['X-Media-Password'] = password;
      final response =
          await client.send(request).timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw Exception('Не удалось скачать вложение');
      }
      final directory =
          await Directory.systemTemp.createTemp('smart_notes_attachment_');
      final safeName = name.replaceAll(RegExp(r'[/\\]'), '_');
      local = '${directory.path}/${safeName.isEmpty ? 'attachment' : safeName}';
      final sink = File(local).openWrite();
      try {
        await response.stream.pipe(sink);
      } catch (_) {
        await directory.delete(recursive: true);
        rethrow;
      }
    } finally {
      client.close();
    }
  }
  final result = await OpenFilex.open(local);
  if (result.type != ResultType.done) throw Exception(result.message);
}
