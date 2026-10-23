import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note_drawing_model.dart';
import '../models/note_model.dart';
import '../models/note_video_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notes_provider.dart';
import '../services/api_config.dart';
import '../widgets/note_drawing_canvas.dart';
import '../widgets/note_drawing_toolbar.dart';
import '../widgets/voice_message_player.dart';
import 'video_player_screen.dart';

class NoteViewScreen extends StatefulWidget {
  final Note note;
  final bool initiallyUnlocked;

  const NoteViewScreen({
    super.key,
    required this.note,
    this.initiallyUnlocked = false,
  });

  @override
  State<NoteViewScreen> createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen> {
  late bool _isLocked;
  Note? _unlockedNote;
  NoteDrawing _drawing = NoteDrawing.empty();
  bool _isDrawingMode = false;
  bool _drawingDirty = false;
  bool _savingDrawing = false;
  DrawingTool _drawingTool = DrawingTool.pen;
  Color _drawingColor = Colors.black;
  double _drawingWidth = 0.012;
  final List<NoteDrawing> _drawingUndoStack = [];
  final List<NoteDrawing> _drawingRedoStack = [];

  @override
  void initState() {
    super.initState();
    _isLocked = widget.note.hasProtection && !widget.initiallyUnlocked;
    _drawing = NoteDrawing.decode(widget.note.drawingData);
    if (_isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestUnlock());
    }
  }

  Future<void> _requestUnlock() async {
    if (!_isLocked) return;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProtectedViewPasswordDialog(),
    );

    if (!mounted) return;
    if (password == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final unlocked = await context.read<NotesProvider>().verifyNotePassword(
            widget.note,
            password: password,
            token: context.read<AuthProvider>().token,
          );
      if (!mounted) return;
      setState(() {
        _unlockedNote = unlocked;
        _drawing = NoteDrawing.decode(unlocked.drawingData);
        _drawingUndoStack.clear();
        _drawingRedoStack.clear();
        _drawingDirty = false;
        _isLocked = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) return _buildLockedScreen();

    final note = _unlockedNote ?? widget.note;
    final token = context.read<AuthProvider>().token;
    final mediaPassword = note.protectionPassword;
    final imagePaths = [
      if (note.imagePath != null && note.imagePath!.isNotEmpty) note.imagePath!,
      ...note.photoPaths,
    ];
    final image = _imageProvider(note.imagePath, token, mediaPassword);
    final backgroundColor = note.color;
    final textColor = _contrastColor(backgroundColor);
    final secondaryTextColor = textColor.withValues(alpha: 0.78);
    final strings = context.strings;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final contentPadding = EdgeInsets.fromLTRB(
      20 + viewPadding.left,
      8,
      20 + viewPadding.right,
      28,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: textColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          tooltip: strings.back,
          onPressed: _isDrawingMode
              ? () => unawaited(_saveDrawingAndClose())
              : () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _savingDrawing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  )
                : Icon(_isDrawingMode ? Icons.check : Icons.brush_outlined),
            tooltip: _isDrawingMode ? strings.save : strings.drawOnNote,
            onPressed: _savingDrawing
                ? null
                : () {
                    if (_isDrawingMode) {
                      unawaited(_saveDrawingAndClose());
                    } else {
                      _enterDrawingMode();
                    }
                  },
          ),
          if (note.hasProtection)
            Tooltip(
              message: strings.protectedNote,
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.lock, size: 20),
              ),
            ),
          if (note.isPending)
            Tooltip(
              message: strings.notUploaded,
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.cloud_off, size: 20, color: Colors.orange),
              ),
            ),
        ],
      ),
      body: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: _isDrawingMode
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: contentPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (image != null) ...[
                                  GestureDetector(
                                    onTap: _isDrawingMode
                                        ? null
                                        : () => _openImageGallery(
                                              imagePaths,
                                              0,
                                              token,
                                              mediaPassword,
                                            ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image(
                                        image: image,
                                        width: double.infinity,
                                        height: 220,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                Text(
                                  note.title.isNotEmpty
                                      ? note.title
                                      : strings.noTitle,
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Georgia',
                                    height: 1.15,
                                  ).copyWith(color: textColor),
                                ),
                                const SizedBox(height: 18),
                                if (note.body.isNotEmpty)
                                  MarkdownBody(
                                    data: note.body,
                                    selectable: !_isDrawingMode,
                                    softLineBreak: true,
                                    styleSheet: MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      p: TextStyle(
                                        fontSize: 17,
                                        height: 1.45,
                                        color: textColor,
                                      ),
                                      h1: TextStyle(
                                        fontSize: 28,
                                        height: 1.18,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                      h2: TextStyle(
                                        fontSize: 24,
                                        height: 1.22,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                      h3: TextStyle(
                                        fontSize: 20,
                                        height: 1.26,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                      blockquote: TextStyle(
                                        fontSize: 17,
                                        height: 1.45,
                                        color: secondaryTextColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      code: TextStyle(
                                        color: textColor,
                                        backgroundColor:
                                            textColor.withValues(alpha: 0.10),
                                      ),
                                      listBullet: TextStyle(color: textColor),
                                      a: TextStyle(
                                        color: textColor,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    onTapLink: (_, href, __) => _isDrawingMode
                                        ? null
                                        : _openMarkdownLink(href),
                                  )
                                else
                                  Text(
                                    strings.noText,
                                    style: TextStyle(
                                      fontSize: 17,
                                      height: 1.45,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                if (note.voicePath != null) ...[
                                  const SizedBox(height: 24),
                                  VoiceMessagePlayer(
                                    path: note.voicePath!,
                                    token: token,
                                    mediaPassword: mediaPassword,
                                  ),
                                ],
                                if (note.photoPaths.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: note.photoPaths.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 1,
                                    ),
                                    itemBuilder: (context, index) {
                                      final provider = _imageProvider(
                                        note.photoPaths[index],
                                        token,
                                        mediaPassword,
                                      );
                                      if (provider == null) {
                                        return const SizedBox.shrink();
                                      }
                                      final galleryIndex =
                                          note.imagePath == null ||
                                                  note.imagePath!.isEmpty
                                              ? index
                                              : index + 1;
                                      return GestureDetector(
                                        onTap: _isDrawingMode
                                            ? null
                                            : () => _openImageGallery(
                                                  imagePaths,
                                                  galleryIndex,
                                                  token,
                                                  mediaPassword,
                                                ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image(
                                            image: provider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                                if (note.videos.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildVideoGrid(note.videos),
                                ],
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: NoteDrawingCanvas(
                              drawing: _drawing,
                              readOnly: !_isDrawingMode,
                              tool: _drawingTool,
                              strokeColor: _drawingColor,
                              strokeWidth: _drawingWidth,
                              onChangeStart: _rememberDrawingForUndo,
                              onChanged: _replaceDrawing,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isDrawingMode) _buildDrawingToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingToolbar() {
    return NoteDrawingToolbar(
      selectedTool: _drawingTool,
      selectedColor: _drawingColor,
      selectedWidth: _drawingWidth,
      canUndo: _drawingUndoStack.isNotEmpty,
      canRedo: _drawingRedoStack.isNotEmpty,
      canClear: _drawing.hasContent,
      onToolSelected: (tool) => setState(() => _drawingTool = tool),
      onColorSelected: (color) => setState(() {
        _drawingColor = color;
        _drawingTool = DrawingTool.pen;
      }),
      onWidthChanged: (width) => setState(() => _drawingWidth = width),
      onUndo: _undoDrawing,
      onRedo: _redoDrawing,
      onClear: _clearDrawing,
      onClose: () => unawaited(_saveDrawingAndClose()),
    );
  }

  void _enterDrawingMode() {
    setState(() => _isDrawingMode = true);
  }

  Future<void> _saveDrawingAndClose() async {
    if (_savingDrawing) return;
    if (!_drawingDirty) {
      setState(() => _isDrawingMode = false);
      return;
    }

    final current = _unlockedNote ?? widget.note;
    final drawingData = _drawing.hasContent ? _drawing.encode() : null;
    final updated = current.copyWith(
      drawingData: drawingData,
      clearDrawingData: drawingData == null,
    );

    setState(() => _savingDrawing = true);
    try {
      await context.read<NotesProvider>().updateNote(
            updated,
            token: context.read<AuthProvider>().token,
          );
      if (!mounted) return;
      setState(() {
        _unlockedNote = updated;
        _isDrawingMode = false;
        _drawingDirty = false;
        _savingDrawing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingDrawing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _rememberDrawingForUndo() {
    if (_drawingUndoStack.isNotEmpty &&
        identical(_drawingUndoStack.last, _drawing)) {
      return;
    }
    _drawingUndoStack.add(_drawing);
    _drawingRedoStack.clear();
  }

  void _replaceDrawing(NoteDrawing drawing) {
    setState(() {
      _drawing = drawing;
      _drawingDirty = true;
    });
  }

  void _undoDrawing() {
    if (_drawingUndoStack.isEmpty) return;
    setState(() {
      _drawingRedoStack.add(_drawing);
      _drawing = _drawingUndoStack.removeLast();
      _drawingDirty = true;
    });
  }

  void _redoDrawing() {
    if (_drawingRedoStack.isEmpty) return;
    setState(() {
      _drawingUndoStack.add(_drawing);
      _drawing = _drawingRedoStack.removeLast();
      _drawingDirty = true;
    });
  }

  void _clearDrawing() {
    if (!_drawing.hasContent) return;
    _rememberDrawingForUndo();
    setState(() {
      _drawing = NoteDrawing.empty();
      _drawingDirty = true;
    });
  }

  Widget _buildVideoGrid(List<NoteVideo> videos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.video,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) => _VideoViewTile(
            video: videos[index],
            onTap: () => _openVideo(videos[index]),
          ),
        ),
      ],
    );
  }

  Future<void> _openVideo(NoteVideo video) async {
    final storagePath = video.storagePath?.trim() ?? '';
    if (storagePath.isNotEmpty) {
      final note = _unlockedNote ?? widget.note;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteVideoPlayerScreen(
            video: video,
            token: context.read<AuthProvider>().token,
            mediaPassword: note.protectionPassword,
          ),
        ),
      );
      return;
    }

    final sourceUrl = video.sourceUrl.trim();
    if (sourceUrl.isEmpty) {
      _showVideoLink(video);
      return;
    }

    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || !uri.hasScheme) {
      _showVideoLink(video);
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showVideoLink(video);
    } catch (_) {
      if (mounted) _showVideoLink(video);
    }
  }

  Future<void> _openMarkdownLink(String? href) async {
    if (href == null || href.trim().isEmpty) return;
    final uri = Uri.tryParse(href.trim());
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showVideoLink(NoteVideo video) {
    final strings = context.readStrings;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          video.title.isNotEmpty ? video.title : strings.video,
        ),
        content: SelectableText(
          video.sourceUrl.isNotEmpty
              ? video.sourceUrl
              : strings.videoLinkUnavailable,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }

  void _openImageGallery(
    List<String> paths,
    int initialIndex,
    String? token,
    String? mediaPassword,
  ) {
    if (paths.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageGallery(
          paths: paths,
          initialIndex: initialIndex,
          token: token,
          mediaPassword: mediaPassword,
        ),
      ),
    );
  }

  Widget _buildLockedScreen() {
    final strings = context.strings;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              Text(
                strings.protectedNote,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.enterPasswordToReadNote,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestUnlock,
                icon: const Icon(Icons.lock_open),
                label: Text(strings.enterPasswordButton),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _imageProvider(
    String? path,
    String? token,
    String? mediaPassword,
  ) {
    if (path == null) return null;
    if (path.startsWith('assets/')) return AssetImage(path);
    if (isRemoteMedia(path)) {
      return NetworkImage(
        resolveMediaUrl(path),
        headers: _mediaHeaders(token, mediaPassword),
      );
    }
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }

  Color _contrastColor(Color color) {
    return color.computeLuminance() < 0.45 ? Colors.white : Colors.black87;
  }

  Map<String, String>? _mediaHeaders(String? token, String? mediaPassword) {
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (mediaPassword != null && mediaPassword.isNotEmpty) {
      headers['X-Media-Password'] = mediaPassword;
    }
    return headers.isEmpty ? null : headers;
  }
}

class _VideoViewTile extends StatelessWidget {
  final NoteVideo video;
  final VoidCallback onTap;

  const _VideoViewTile({
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _VideoViewThumbnail(thumbnailUrl: video.thumbnailPath),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title.isNotEmpty
                        ? video.title
                        : context.strings.video,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${video.provider} · ${video.status}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Center(
              child:
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoViewThumbnail extends StatelessWidget {
  final String? thumbnailUrl;

  const _VideoViewThumbnail({this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl ?? '';
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _VideoViewPlaceholder(),
      );
    }
    return const _VideoViewPlaceholder();
  }
}

class _VideoViewPlaceholder extends StatelessWidget {
  const _VideoViewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(Icons.video_library_outlined, color: Colors.white70),
      ),
    );
  }
}

class _FullscreenImageGallery extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final String? token;
  final String? mediaPassword;

  const _FullscreenImageGallery({
    required this.paths,
    required this.initialIndex,
    required this.token,
    required this.mediaPassword,
  });

  @override
  State<_FullscreenImageGallery> createState() =>
      _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<_FullscreenImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.initialIndex.clamp(0, widget.paths.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.paths.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final provider = _imageProvider(widget.paths[index]);
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image(
                      image: provider,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: context.strings.back,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.paths.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _imageProvider(String path) {
    if (path.startsWith('assets/')) return AssetImage(path);
    if (isRemoteMedia(path)) {
      return NetworkImage(
        resolveMediaUrl(path),
        headers: _mediaHeaders(),
      );
    }
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
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
}

class _ProtectedViewPasswordDialog extends StatefulWidget {
  const _ProtectedViewPasswordDialog();

  @override
  State<_ProtectedViewPasswordDialog> createState() =>
      _ProtectedViewPasswordDialogState();
}

class _ProtectedViewPasswordDialogState
    extends State<_ProtectedViewPasswordDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.protectedNote),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.strings.enterPasswordToReadNote),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.strings.password,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _passwordCtrl.text),
          child: Text(context.strings.open),
        ),
      ],
    );
  }
}
