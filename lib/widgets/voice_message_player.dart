import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;

import '../providers/locale_provider.dart';
import '../services/api_config.dart';

/// Проигрыватель голосовой заметки: play/pause, перематываемый прогресс,
/// тайминги и кнопка удаления. Держит собственный `FlutterSoundPlayer`.
///
/// `path` может быть:
///  - локальным путём (свежая запись до сохранения),
///  - серверным URL/относительным путём (`/uploads/voice/...`) — тогда файл
///    сначала скачивается во временный кэш, затем воспроизводится.
class VoiceMessagePlayer extends StatefulWidget {
  final String path;
  final Duration? initialDuration;
  final VoidCallback? onDelete;
  final String? token; // нужен для скачивания защищённого файла с бэкенда
  final String? mediaPassword;

  const VoiceMessagePlayer({
    super.key,
    required this.path,
    this.onDelete,
    this.initialDuration,
    this.token,
    this.mediaPassword,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription<PlaybackDisposition>? _sub;
  bool _ready = false;
  bool _preparing = false;
  String? _error;
  String? _playablePath; // локальный файл, готовый к воспроизведению
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration ?? Duration.zero;
    _open();
  }

  Future<void> _open() async {
    await _player.openPlayer();
    await _player.setSubscriptionDuration(const Duration(milliseconds: 100));
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  // Готовит локальный файл для воспроизведения (скачивает удалённый при нужде).
  Future<void> _prepareSource() async {
    final strings = context.readStrings;
    if (_playablePath != null) return;
    if (!isRemoteMedia(widget.path)) {
      _playablePath = widget.path;
      return;
    }
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      final cache = File(
          '${Directory.systemTemp.path}/voice_cache_${widget.path.hashCode}.aac');
      if (!await cache.exists() || await cache.length() == 0) {
        final resp = await http
            .get(
              Uri.parse(resolveMediaUrl(widget.path)),
              headers: _mediaHeaders(),
            )
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode >= 400) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        await cache.writeAsBytes(resp.bodyBytes);
      }
      _playablePath = cache.path;
    } catch (_) {
      _error = strings.audioLoadFailed;
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Map<String, String>? _mediaHeaders() {
    final headers = <String, String>{};
    if (widget.token != null && widget.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${widget.token}';
    }
    if (widget.mediaPassword != null && widget.mediaPassword!.isNotEmpty) {
      headers['X-Media-Password'] = widget.mediaPassword!;
    }
    return headers.isEmpty ? null : headers;
  }

  Future<void> _toggle() async {
    if (!_ready || _preparing) return;

    if (_player.isPlaying) {
      await _player.pausePlayer();
    } else if (_player.isPaused) {
      await _player.resumePlayer();
    } else {
      await _prepareSource();
      if (_playablePath == null) return; // ошибка загрузки
      await _player.startPlayer(
        fromURI: _playablePath,
        whenFinished: () {
          if (mounted) setState(() => _position = Duration.zero);
        },
      );
      _sub ??= _player.onProgress!.listen((e) {
        if (!mounted) return;
        setState(() {
          _position = e.position;
          if (e.duration > Duration.zero) _duration = e.duration;
        });
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _seek(double fraction) async {
    if (_duration == Duration.zero) return;
    final target = _duration * fraction;
    await _player.seekToPlayer(target);
    if (mounted) setState(() => _position = target);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds;
    final fraction =
        total == 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _buildPlayButton(),
          Expanded(
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: fraction,
                          onChanged: total == 0 ? null : _seek,
                          activeColor: Colors.black,
                          inactiveColor: Colors.grey.shade400,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(_position),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text(_fmt(_duration),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (widget.onDelete != null)
            IconButton(
              onPressed: widget.onDelete,
              color: Colors.red,
              icon: const Icon(Icons.delete_outline),
              tooltip: context.strings.delete,
            ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    if (_preparing) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(9),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      onPressed: _ready ? _toggle : null,
      iconSize: 40,
      color: Colors.black,
      icon: Icon(
        _player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
      ),
    );
  }
}
