import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/note_video_model.dart';
import '../providers/locale_provider.dart';
import '../services/api_config.dart';

class NoteVideoPlayerScreen extends StatefulWidget {
  final NoteVideo video;
  final String? token;
  final String? mediaPassword;

  const NoteVideoPlayerScreen({
    super.key,
    required this.video,
    this.token,
    this.mediaPassword,
  });

  @override
  State<NoteVideoPlayerScreen> createState() => _NoteVideoPlayerScreenState();
}

class _NoteVideoPlayerScreenState extends State<NoteVideoPlayerScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final path = widget.video.storagePath?.trim() ?? '';
    if (path.isEmpty) {
      setState(() => _error = context.readStrings.videoFileUnavailable);
      return;
    }

    final url = resolveMediaUrl(path);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      setState(() => _error = context.readStrings.invalidVideoPath);
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: _mediaHeaders(),
    );
    _controller = controller;
    _initializeFuture = controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _error = context.readStrings.videoOpenFailed);
    });
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video.title.isNotEmpty
        ? widget.video.title
        : context.strings.video;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    final controller = _controller;
    final initializeFuture = _initializeFuture;
    if (controller == null || initializeFuture == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator(color: Colors.white);
        }

        final aspectRatio = controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            _VideoControls(controller: controller),
          ],
        );
      },
    );
  }

  Map<String, String> _mediaHeaders() {
    final headers = <String, String>{};
    if (widget.token != null && widget.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${widget.token}';
    }
    if (widget.mediaPassword != null && widget.mediaPassword!.isNotEmpty) {
      headers['X-Media-Password'] = widget.mediaPassword!;
    }
    return headers;
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            widget.controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.white,
                  size: 34,
                ),
                tooltip: value.isPlaying
                    ? context.strings.pause
                    : context.strings.play,
                onPressed: () {
                  value.isPlaying
                      ? widget.controller.pause()
                      : widget.controller.play();
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmt(value.position)} / ${_fmt(value.duration)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
