import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import '../models/note_model.dart';
import '../providers/incoming_share_provider.dart';

/// Получает превью напрямую с сайта, не отправляя заметку в API.
class SharedNoteImporter {
  final http.Client? client;
  const SharedNoteImporter({this.client});

  Note original(IncomingShare share) {
    var title = share.title.trim();
    if (title.isEmpty) {
      title = share.body.trim().split('\n').first;
      if (title.length > 100) title = title.substring(0, 100);
      if (title.isEmpty) {
        title = [...share.images, ...share.files]
            .map((f) => Uri.file(f.path).pathSegments.last)
            .join(', ');
      }
    }
    return Note(
        id: '',
        title: title,
        body: share.body,
        isIncoming: true,
        photoPaths: share.images.map((f) => f.path).toList(),
        attachmentPaths: share.files.map((f) => f.path).toList());
  }

  Future<Note> prepare(IncomingShare share, Directory temporary) async {
    var title = original(share).title;
    var body = share.body;
    String? cover;
    final match = RegExp(r'https?://[^\s<>]+').firstMatch(body);
    final url = match == null
        ? null
        : Uri.tryParse(
            match.group(0)!.replaceFirst(RegExp(r'[.,;:!?)}\]]+$'), ''));
    final active = client ?? http.Client();
    try {
      if (url != null && url.hasAuthority) {
        final page = await _get(active, url, 2 * 1024 * 1024);
        if (page != null) {
          final document = html.parse(utf8.decode(page, allowMalformed: true));
          String meta(String key) =>
              document
                  .querySelector('meta[property="$key"], meta[name="$key"]')
                  ?.attributes['content']
                  ?.trim() ??
              '';
          final pageTitle = meta('og:title').isNotEmpty
              ? meta('og:title')
              : document.querySelector('title')?.text.trim() ?? '';
          if (pageTitle.isNotEmpty) title = pageTitle;
          final description = meta('og:description').isNotEmpty
              ? meta('og:description')
              : meta('description');
          final paragraphs = document
              .querySelectorAll('article p, main p')
              .map((p) => p.text.replaceAll(RegExp(r'\s+'), ' ').trim())
              .where((text) => text.length > 40)
              .take(16)
              .toList();
          var text =
              paragraphs.isNotEmpty ? paragraphs.join('\n\n') : description;
          if (text.length > 8000) text = text.substring(0, 8000);
          body = [share.body, if (text.isNotEmpty) text].join('\n\n');
          final image = meta('og:image').isNotEmpty
              ? meta('og:image')
              : meta('twitter:image');
          if (image.isNotEmpty) {
            try {
              final data =
                  await _get(active, url.resolve(image), 8 * 1024 * 1024);
              // Сохраняем только форматы, которые можно показать без конвертации.
              if (data != null &&
                  data.length > 8 &&
                  ((data[0] == 255 && data[1] == 216) ||
                      (data[0] == 137 && data[1] == 80))) {
                final file = File(
                    '${temporary.path}/cover.${data[0] == 255 ? 'jpg' : 'png'}');
                await file.writeAsBytes(data, flush: true);
                cover = file.path;
              }
            } catch (_) {/* Ссылка сохраняется и без обложки. */}
          }
        }
      }
    } catch (_) {
      /* Офлайн и закрытые сайты: сохраняем исходный контент. */
    } finally {
      if (client == null) active.close();
    }
    if (title.trim().isEmpty) {
      title = body.trim().split('\n').first;
      if (title.length > 100) title = title.substring(0, 100);
      if (title.isEmpty) {
        title = [...share.images, ...share.files]
            .map((f) => Uri.file(f.path).pathSegments.last)
            .join(', ');
      }
    }
    return Note(
        id: '',
        title: title,
        body: body,
        isIncoming: true,
        imagePath: cover,
        photoPaths: share.images.map((f) => f.path).toList(),
        attachmentPaths: share.files.map((f) => f.path).toList());
  }

  Future<List<int>?> _get(http.Client client, Uri url, int limit) async {
    if (url.scheme != 'https' && url.scheme != 'http') return null;
    return (() async {
      final response = await client.send(http.Request('GET', url)
        ..headers['Accept'] = 'text/html,image/*'
        ..headers['User-Agent'] = 'SmartNotes/1.0');
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        return null;
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > limit) {
          throw const FormatException('Превью слишком большое');
        }
        bytes.addAll(chunk);
      }
      return bytes;
    })()
        .timeout(const Duration(seconds: 7));
  }
}
