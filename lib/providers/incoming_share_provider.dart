import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class IncomingShare {
  final String id;
  final String title;
  final String body;
  final List<SharedMediaFile> images;
  final List<SharedMediaFile> files;
  final int unsupportedFileCount;

  const IncomingShare({
    required this.id,
    required this.title,
    required this.body,
    required this.images,
    this.files = const [],
    required this.unsupportedFileCount,
  });

  factory IncomingShare.fromMedia(List<SharedMediaFile> media) {
    final textParts = <String>[];
    final imageFiles = <SharedMediaFile>[];
    final files = <SharedMediaFile>[];
    const unsupported = 0;

    for (final item in media) {
      switch (item.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          if (item.path.trim().isNotEmpty) textParts.add(item.path.trim());
          if ((item.message ?? '').trim().isNotEmpty) {
            textParts.add(item.message!.trim());
          }
        case SharedMediaType.image:
          imageFiles.add(item);
          if ((item.message ?? '').trim().isNotEmpty) {
            textParts.add(item.message!.trim());
          }
        case SharedMediaType.video:
        case SharedMediaType.file:
          files.add(item);
          if ((item.message ?? '').trim().isNotEmpty) {
            textParts.add(item.message!.trim());
          }
      }
    }

    final body = textParts.toSet().join('\n\n');
    final firstUrl = _extractUrl(body);
    final title = firstUrl == null ? '' : (Uri.tryParse(firstUrl)?.host ?? '');
    final stableId =
        media.map((item) => '${item.type.value}:${item.path}').join('|');
    return IncomingShare(
      id: stableId,
      title: title,
      body: body,
      images: List.unmodifiable(imageFiles),
      files: List.unmodifiable(files),
      unsupportedFileCount: unsupported,
    );
  }

  static String? _extractUrl(String text) {
    final match =
        RegExp(r'https?://[^\s<>]+', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    var value = match.group(0)!;
    while (value.isNotEmpty && '.,;:!?)]}'.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    return Uri.tryParse(value)?.hasAuthority == true ? value : null;
  }
}

class IncomingShareProvider extends ChangeNotifier {
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final Queue<IncomingShare> _pending = Queue<IncomingShare>();
  final Set<String> _recentIds = <String>{};
  bool _initialized = false;

  IncomingShare? get pending => _pending.isEmpty ? null : _pending.first;

  IncomingShareProvider() {
    initialize();
  }

  void initialize() {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _accept,
      onError: (Object error) {
        // ignore: avoid_print
        print('[SHARE] incoming stream error: $error');
      },
    );
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    try {
      _accept(await ReceiveSharingIntent.instance.getInitialMedia());
    } catch (error) {
      // ignore: avoid_print
      print('[SHARE] initial share error: $error');
    }
  }

  void _accept(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final share = IncomingShare.fromMedia(files);
    if (share.id.isEmpty || !_recentIds.add(share.id)) return;
    if (_recentIds.length > 16) _recentIds.remove(_recentIds.first);
    _pending.add(share);
    Timer(const Duration(seconds: 3), () => _recentIds.remove(share.id));
    notifyListeners();
  }

  IncomingShare? takePending() {
    if (_pending.isEmpty) return null;
    final share = _pending.removeFirst();
    unawaited(ReceiveSharingIntent.instance.reset());
    notifyListeners();
    return share;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
