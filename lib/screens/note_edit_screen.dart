import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../models/note_model.dart';
import '../models/note_video_model.dart';
import '../models/video_preview_model.dart';
import '../providers/notes_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_config.dart';
import '../widgets/color_picker_menu.dart';
import '../widgets/voice_message_player.dart';
import 'video_player_screen.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? initialNote;
  final bool initiallyUnlocked;

  const NoteEditScreen({
    super.key,
    this.initialNote,
    this.initiallyUnlocked = false,
  });

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final FocusNode _bodyFocusNode;
  late Color _selectedColor;

  String? _coverImagePath;
  XFile? _coverImageFile;
  final List<_EditableImage> _photos = [];
  bool _isRecording = false;
  String? _recordedPath;
  int _recordSeconds = 0;
  int _recordedDuration = 0; // длительность завершённой записи, сек
  Timer? _timer;
  bool _isProtected = false;
  String? _protectionPassword;
  bool _isHidden = false;
  String? _hiddenKeyId;
  bool _showBodyPreview = false;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late AnimationController _animController;
  late AnimationController _pulseController;

  bool _saving = false;
  bool _syncing = false;
  bool _deleting = false;
  bool _isLocked = false;
  Note? _currentNote;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    _currentNote = note;

    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _bodyFocusNode = FocusNode();
    _selectedColor = note?.color ?? Colors.white;
    _isProtected = note?.hasProtection ?? false;
    _protectionPassword = note?.protectionPassword;
    _isHidden = note?.isHidden ?? false;
    _hiddenKeyId = note?.hiddenKeyId;
    _isLocked = _isProtected && !widget.initiallyUnlocked;

    _coverImagePath = note?.imagePath;
    _photos.addAll(
      (note?.photoPaths ?? const []).map((path) => _EditableImage(path: path)),
    );
    if (note?.isVoice == true) _recordedPath = note?.voicePath;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _recorder.openRecorder();

    if (_isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestUnlock());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _recorder.closeRecorder();
    _animController.dispose();
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _hasImage => _coverImagePath != null && _coverImagePath!.isNotEmpty;

  Future<void> _requestUnlock() async {
    final note = widget.initialNote;
    if (note == null || !_isLocked) return;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProtectedNoteUnlockDialog(),
    );

    if (!mounted) return;
    if (password == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final unlocked = await context.read<NotesProvider>().verifyNotePassword(
            note,
            password: password,
            token: context.read<AuthProvider>().token,
          );
      if (!mounted) return;
      setState(() {
        _currentNote = unlocked;
        _titleController.text = unlocked.title;
        _bodyController.text = unlocked.body;
        _selectedColor = unlocked.color;
        _coverImagePath = unlocked.imagePath;
        _coverImageFile = null;
        _photos
          ..clear()
          ..addAll(
            unlocked.photoPaths.map((path) => _EditableImage(path: path)),
          );
        _recordedPath = unlocked.voicePath;
        _isProtected = unlocked.hasProtection;
        _isHidden = unlocked.isHidden;
        _hiddenKeyId = unlocked.hiddenKeyId;
        _protectionPassword = password;
        _isLocked = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  Future<void> _onColorSelected(Color color) async {
    if (_hasImage) {
      final strings = context.readStrings;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.replaceImageQuestion),
          content: Text(strings.replaceImageMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                strings.replace,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _coverImagePath = null);
    }
    setState(() => _selectedColor = color);
  }

  Future<void> _pickCoverImage() async {
    final source = await _showImageSourceSheet(
      title: context.readStrings.coverImage,
      allowGalleryMultiple: false,
    );
    if (source == null) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _coverImagePath = picked.path;
        _coverImageFile = picked;
      });
    }
  }

  Future<void> _addPhotos() async {
    final source = await _showImageSourceSheet(
      title: context.readStrings.notePhotos,
      allowGalleryMultiple: true,
    );
    if (source == null) return;

    if (source == ImageSource.camera) {
      final picked =
          await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(
          () => _photos.add(_EditableImage(path: picked.path, file: picked)),
        );
      }
      return;
    }

    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(
        () => _photos.addAll(
          picked.map((file) => _EditableImage(path: file.path, file: file)),
        ),
      );
    }
  }

  Future<ImageSource?> _showImageSourceSheet({
    required String title,
    required bool allowGalleryMultiple,
  }) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(ctx.strings.takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                allowGalleryMultiple
                    ? ctx.strings.chooseOneOrMorePhotos
                    : ctx.strings.chooseFromGallery,
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _removePhotoAt(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.readStrings.micPermissionRequired),
          ),
        );
        return;
      }

      // Уникальное имя, чтобы новая запись не путалась с прежним файлом.
      final path =
          '${Directory.systemTemp.path}/note_voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: path);
      setState(() {
        _isRecording = true;
        _recordedPath = path;
        _recordSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordSeconds += 1);
      });
    } else {
      await _recorder.stopRecorder();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _recordedDuration = _recordSeconds;
      });
    }
  }

  Future<void> _deleteRecording() async {
    if (_isRecording) {
      await _recorder.stopRecorder();
      _timer?.cancel();
    }
    // Временный файл записи чистим; сохранённые заметки удаляют файл при сохранении.
    final path = _recordedPath;
    if (path != null && path.contains('note_voice_')) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordedPath = null;
      _recordedDuration = 0;
      _recordSeconds = 0;
    });
  }

  Future<void> _syncNote() async {
    if (_syncing) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    final token = auth.token;
    if (userId == null || token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.readStrings.authRequiredToSend)),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      await context.read<NotesProvider>().syncNote(
            _currentNote!,
            userId: userId,
            token: token,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _saveNote() async {
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<NotesProvider>();
    final auth = context.read<AuthProvider>();
    String? imagePath = _coverImagePath;
    List<_EditableImage> photos = List.of(_photos);

    try {
      imagePath = await _uploadImagePath(
        imagePath,
        _coverImageFile,
        auth,
        provider,
      );
      final uploadedPhotoPaths = <String>[];
      for (final photo in photos) {
        final uploaded = await _uploadImagePath(
          photo.path,
          photo.file,
          auth,
          provider,
        );
        if (uploaded != null) uploadedPhotoPaths.add(uploaded);
      }
      final photoPaths = uploadedPhotoPaths;

      // Свежую локальную запись заливаем на сервер → в заметке будет URL.
      String? voicePath = _recordedPath;
      if (voicePath != null &&
          !isRemoteMedia(voicePath) &&
          auth.token != null &&
          auth.token!.isNotEmpty) {
        final file = File(voicePath);
        if (await file.exists()) {
          try {
            voicePath = await provider.uploadVoice(
              file,
              auth.token!,
              mediaPassword: _isProtected ? _protectionPassword : null,
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.readStrings.voiceNotUploadedLocal),
                  backgroundColor: Colors.orange[800],
                ),
              );
            }
            // оставляем локальный путь — заметка сохранится, голос локальный
          }
        }
      }

      final drawingData = _currentNote?.drawingData;

      if (_isEditing) {
        final updated = _currentNote!.copyWith(
          title: _titleController.text,
          body: _bodyController.text,
          drawingData: drawingData,
          clearDrawingData: drawingData == null,
          imagePath: imagePath,
          photoPaths: photoPaths,
          clearImagePath: imagePath == null,
          voicePath: voicePath,
          clearVoicePath: voicePath == null,
          isVoice: voicePath != null,
          color: _selectedColor,
          isProtected: _isProtected,
          protectionPassword: _protectionPassword,
          clearProtectionPassword: !_isProtected,
          isHidden: _isHidden,
          hiddenKeyId: _isHidden ? _hiddenKeyId : null,
          clearHiddenKeyId: !_isHidden,
        );
        await provider.updateNote(updated, token: auth.token);
      } else {
        await provider.addNote(
          Note(
            id: '',
            title: _titleController.text,
            body: _bodyController.text,
            drawingData: null,
            imagePath: imagePath,
            photoPaths: photoPaths,
            voicePath: voicePath,
            isVoice: voicePath != null,
            color: _selectedColor,
            isProtected: _isProtected,
            protectionPassword: _isProtected ? _protectionPassword : null,
            isHidden: _isHidden,
            hiddenKeyId: _isHidden ? _hiddenKeyId : null,
          ),
          userId: auth.userId,
          token: auth.token,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _uploadImagePath(
    String? path,
    XFile? pickedFile,
    AuthProvider auth,
    NotesProvider provider,
  ) async {
    if (path == null || path.isEmpty || path.startsWith('assets/')) {
      return path;
    }
    if (isRemoteMedia(path) || auth.token == null || auth.token!.isEmpty) {
      return path;
    }

    try {
      if (pickedFile != null) {
        return await provider.uploadPickedImage(
          pickedFile,
          auth.token!,
          mediaPassword: _isProtected ? _protectionPassword : null,
        );
      }
      if (kIsWeb) return path;

      final file = File(path);
      if (!await file.exists()) return path;
      return await provider.uploadImage(
        file,
        auth.token!,
        mediaPassword: _isProtected ? _protectionPassword : null,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.readStrings.imageNotUploadedLocal),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
      return path;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) return _buildLockedScreen();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _buildImagePreview(),
                    _buildTextFields(),
                    _buildPhotoGallery(),
                    _buildVoiceSection(),
                    _buildVideoSection(),
                  ],
                ),
              ),
            ),
            _buildBottomActions(),
          ],
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
                strings.enterPasswordToReadAndEditNote,
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

  Widget _buildTopBar() {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          Row(
            children: [
              if (_isEditing && _currentNote!.isPending) ...[
                _syncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.orange,
                        ),
                        tooltip: strings.uploadToServer,
                        onPressed: _syncNote,
                      ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: Icon(
                  Icons.visibility_off,
                  color: _isHidden ? Colors.black87 : Colors.grey[600],
                ),
                tooltip:
                    _isHidden ? strings.removeNfcHiding : strings.hideNoteByNfc,
                onPressed: _toggleHiddenNote,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_isProtected ? Icons.lock : Icons.lock_open),
                tooltip: _isProtected
                    ? strings.changeProtection
                    : strings.protectNote,
                onPressed: _showProtectionDialog,
              ),
              const SizedBox(width: 8),
              if (_isEditing) ...[
                IconButton(
                  icon: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: strings.deleteNote,
                  onPressed: _deleting ? null : _confirmDeleteNote,
                ),
                const SizedBox(width: 8),
              ],
              ColorPickerMenu(
                selectedColor: _selectedColor,
                onColorSelected: _onColorSelected,
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNote() async {
    final note = _currentNote;
    if (note == null) return;
    final strings = context.readStrings;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteNoteQuestion),
        content: Text(
          note.title.isNotEmpty ? '«${note.title}»' : strings.noteWillBeDeleted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              strings.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await context.read<NotesProvider>().deleteNote(
            note.id,
            token: context.read<AuthProvider>().token,
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  Future<void> _showProtectionDialog() async {
    final result = await showDialog<_ProtectionResult>(
      context: context,
      builder: (_) => _NoteProtectionDialog(
        isProtected: _isProtected,
        initialPassword: _protectionPassword,
      ),
    );

    if (result == null || !mounted) return;
    if (_isEditing) {
      try {
        await context.read<NotesProvider>().updateNoteProtection(
              _currentNote!,
              isProtected: result.enabled,
              password: result.password,
              token: context.read<AuthProvider>().token,
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.readStrings.localProtectionWarning),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
    }
    setState(() {
      _isProtected = result.enabled;
      _protectionPassword = result.enabled ? result.password : null;
    });
  }

  void _toggleHiddenNote() {
    if (_isHidden) {
      setState(() {
        _isHidden = false;
        _hiddenKeyId = null;
      });
      return;
    }

    final keyId = context.read<NotesProvider>().activeHiddenKeyId;
    if (keyId == null || keyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.readStrings.openHiddenFirst),
        ),
      );
      return;
    }

    setState(() {
      _isHidden = true;
      _hiddenKeyId = keyId;
    });
  }

  Widget _buildImagePreview() {
    final imageProvider = _coverImagePath == null
        ? null
        : _imageProviderForPath(_coverImagePath!);

    return InkWell(
      onTap: _pickCoverImage,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 200,
        decoration: BoxDecoration(
          color: imageProvider == null ? _selectedColor : Colors.grey[200],
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
          image: imageProvider != null
              ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
              : null,
        ),
        child: Stack(
          children: [
            if (imageProvider == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, size: 32),
                    const SizedBox(height: 8),
                    Text(context.strings.chooseCoverTap),
                  ],
                ),
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery() {
    if (_photos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _photos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final path = _photos[index].path;
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: _imageProviderForPath(path),
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removePhotoAt(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ImageProvider _imageProviderForPath(String path) {
    if (path.startsWith('assets/')) return AssetImage(path);
    if (isRemoteMedia(path)) {
      final token = context.read<AuthProvider>().token;
      return NetworkImage(
        resolveMediaUrl(path),
        headers: _mediaHeaders(token),
      );
    }
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }

  Map<String, String>? _mediaHeaders(String? token) {
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (_isProtected &&
        _protectionPassword != null &&
        _protectionPassword!.isNotEmpty) {
      headers['X-Media-Password'] = _protectionPassword!;
    }
    return headers.isEmpty ? null : headers;
  }

  Widget _buildTextFields() {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
            decoration: InputDecoration(
              hintText: strings.titleHint,
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 4),
          _RichTextToolbar(
            previewEnabled: _showBodyPreview,
            onTogglePreview: () {
              setState(() => _showBodyPreview = !_showBodyPreview);
              if (_showBodyPreview) {
                _bodyFocusNode.unfocus();
              } else {
                _bodyFocusNode.requestFocus();
              }
            },
            onBold: () => _wrapBodySelection('**', '**', strings.boldSample),
            onItalic: () => _wrapBodySelection('_', '_', strings.italicSample),
            onHeading: () => _prefixBodyLines('## ', strings.headingSample),
            onBulletList: () => _prefixBodyLines('- ', strings.listItemSample),
            onNumberedList: () =>
                _prefixBodyLines('1. ', strings.listItemSample),
            onChecklist: () => _prefixBodyLines('- [ ] ', strings.taskSample),
            onQuote: () => _prefixBodyLines('> ', strings.quoteSample),
            onInlineCode: () =>
                _wrapBodySelection('`', '`', strings.codeSample),
            onLink: _insertMarkdownLink,
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _showBodyPreview
                ? _buildBodyPreview(strings)
                : TextField(
                    key: const ValueKey('body-editor'),
                    controller: _bodyController,
                    focusNode: _bodyFocusNode,
                    minLines: 8,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                    decoration: InputDecoration(
                      hintText: strings.bodyHint,
                      border: InputBorder.none,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyPreview(AppStrings strings) {
    final scheme = Theme.of(context).colorScheme;
    final markdown = _bodyController.text.trim();
    return Container(
      key: const ValueKey('body-preview'),
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.topLeft,
      child: markdown.isEmpty
          ? Text(
              strings.formattedTextPreview,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.54),
                fontSize: 16,
              ),
            )
          : MarkdownBody(
              data: markdown,
              selectable: true,
              softLineBreak: true,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(
                p: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: scheme.onSurface,
                ),
                h1: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
                h2: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
                h3: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                blockquote: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  fontStyle: FontStyle.italic,
                ),
                code: TextStyle(
                  color: scheme.onSurface,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
            ),
    );
  }

  void _wrapBodySelection(
    String prefix,
    String suffix,
    String placeholder,
  ) {
    final text = _bodyController.text;
    final selection = _safeBodySelection(text);
    final selected = selection.textInside(text);
    final replacement =
        '$prefix${selected.isEmpty ? placeholder : selected}$suffix';
    _replaceBodySelection(selection, replacement);
  }

  void _prefixBodyLines(String prefix, String placeholder) {
    final text = _bodyController.text;
    final selection = _safeBodySelection(text);
    final selected = selection.textInside(text);
    final source = selected.isEmpty ? placeholder : selected;
    final replacement = source
        .split('\n')
        .map((line) => line.startsWith(prefix) ? line : '$prefix$line')
        .join('\n');
    _replaceBodySelection(selection, replacement);
  }

  void _insertMarkdownLink() {
    final text = _bodyController.text;
    final selection = _safeBodySelection(text);
    final selected = selection.textInside(text).trim();
    final title = selected.isEmpty ? context.readStrings.linkSample : selected;
    _replaceBodySelection(selection, '[$title](https://)');
  }

  TextSelection _safeBodySelection(String text) {
    final selection = _bodyController.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: text.length);
    }
    final start = selection.start.clamp(0, text.length).toInt();
    final end = selection.end.clamp(0, text.length).toInt();
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  void _replaceBodySelection(TextSelection selection, String replacement) {
    final text = _bodyController.text;
    final nextText =
        selection.textBefore(text) + replacement + selection.textAfter(text);
    final nextOffset = selection.start + replacement.length;
    _bodyController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    setState(() => _showBodyPreview = false);
    _bodyFocusNode.requestFocus();
  }

  Widget _buildVoiceSection() {
    if (_isRecording) return _buildRecordingPanel();
    if (_recordedPath != null) {
      return VoiceMessagePlayer(
        key: ValueKey(_recordedPath),
        path: _recordedPath!,
        token: context.read<AuthProvider>().token,
        mediaPassword: _isProtected ? _protectionPassword : null,
        initialDuration:
            _recordedDuration > 0 ? Duration(seconds: _recordedDuration) : null,
        onDelete: _deleteRecording,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildVideoSection() {
    final videos = _currentNote?.videos ?? const <NoteVideo>[];
    if (videos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
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
            itemBuilder: (context, index) => _VideoAttachmentTile(
              video: videos[index],
              onTap: () => _openVideo(videos[index]),
              onDelete: () => _deleteVideo(videos[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulseController,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${context.strings.record}  ${_fmt(Duration(seconds: _recordSeconds))}',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _toggleRecording,
            icon: const Icon(Icons.stop_circle, color: Colors.red),
            label: Text(
              context.strings.stop,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaActions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _animatedIcon(
                _isRecording ? Icons.stop : Icons.mic,
                delay: 0,
                onTap: _toggleRecording,
                background: _isRecording ? Colors.red : Colors.black,
              ),
              const SizedBox(width: 16),
              _animatedIcon(
                Icons.camera_alt,
                delay: 100,
                onTap: _addPhotos,
              ),
              const SizedBox(width: 16),
              _animatedIcon(
                Icons.video_library_outlined,
                delay: 180,
                onTap: _showAddVideoDialog,
              ),
            ],
          );
          final saveButton = ElevatedButton(
            onPressed: _saving ? null : _saveNote,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.strings.saveUpper),
          );

          if (constraints.maxWidth < 320) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                saveButton,
                const SizedBox(height: 16),
                Center(child: mediaActions),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              saveButton,
              mediaActions,
            ],
          );
        },
      ),
    );
  }

  Widget _animatedIcon(IconData icon,
      {required int delay,
      VoidCallback? onTap,
      Color background = Colors.black}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Interval(delay / 300, 1.0, curve: Curves.easeOut),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _showAddVideoDialog() async {
    final note = _currentNote;
    if (!_isEditing || note == null || note.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.readStrings.saveNoteFirstAddVideo),
        ),
      );
      return;
    }
    if (note.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.readStrings.syncNoteFirst)),
      );
      return;
    }
    if (_isProtected || note.hasProtection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.readStrings.protectedVideoUnsupported),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final video = await showDialog<NoteVideo>(
      context: context,
      builder: (_) => _AddVideoDialog(
        note: note,
        token: auth.token,
      ),
    );

    if (video == null || !mounted) return;
    setState(() {
      final current = _currentNote;
      if (current == null) return;
      _currentNote = current.copyWith(
        videos: [...current.videos, video],
        isVideo: true,
      );
    });
  }

  Future<void> _openVideo(NoteVideo video) async {
    final storagePath = video.storagePath?.trim() ?? '';
    if (storagePath.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteVideoPlayerScreen(
            video: video,
            token: context.read<AuthProvider>().token,
            mediaPassword: _isProtected ? _protectionPassword : null,
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

  Future<void> _deleteVideo(NoteVideo video) async {
    final note = _currentNote;
    if (note == null) return;
    final strings = context.readStrings;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteVideoQuestion),
        content: Text(
          video.title.isNotEmpty ? video.title : strings.videoWillBeDeleted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              strings.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<NotesProvider>().deleteVideo(
            note: note,
            videoId: video.id,
            token: context.read<AuthProvider>().token,
          );
      if (!mounted) return;
      setState(() {
        final current = _currentNote;
        if (current == null) return;
        final videos =
            current.videos.where((item) => item.id != video.id).toList();
        _currentNote = current.copyWith(
          videos: videos,
          isVideo: videos.isNotEmpty,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    }
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
}

class _RichTextToolbar extends StatelessWidget {
  final bool previewEnabled;
  final VoidCallback onTogglePreview;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onHeading;
  final VoidCallback onBulletList;
  final VoidCallback onNumberedList;
  final VoidCallback onChecklist;
  final VoidCallback onQuote;
  final VoidCallback onInlineCode;
  final VoidCallback onLink;

  const _RichTextToolbar({
    required this.previewEnabled,
    required this.onTogglePreview,
    required this.onBold,
    required this.onItalic,
    required this.onHeading,
    required this.onBulletList,
    required this.onNumberedList,
    required this.onChecklist,
    required this.onQuote,
    required this.onInlineCode,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _FormatToolButton(
              tooltip: previewEnabled ? strings.editor : strings.preview,
              icon:
                  previewEnabled ? Icons.edit_outlined : Icons.preview_outlined,
              selected: previewEnabled,
              onPressed: onTogglePreview,
            ),
            _ToolbarDivider(color: scheme.outline),
            _FormatToolButton(
              tooltip: strings.bold,
              icon: Icons.format_bold,
              onPressed: onBold,
            ),
            _FormatToolButton(
              tooltip: strings.italic,
              icon: Icons.format_italic,
              onPressed: onItalic,
            ),
            _FormatToolButton(
              tooltip: strings.heading,
              icon: Icons.title,
              onPressed: onHeading,
            ),
            _FormatToolButton(
              tooltip: strings.bulletList,
              icon: Icons.format_list_bulleted,
              onPressed: onBulletList,
            ),
            _FormatToolButton(
              tooltip: strings.numberedList,
              icon: Icons.format_list_numbered,
              onPressed: onNumberedList,
            ),
            _FormatToolButton(
              tooltip: strings.checklist,
              icon: Icons.check_box_outlined,
              onPressed: onChecklist,
            ),
            _FormatToolButton(
              tooltip: strings.quote,
              icon: Icons.format_quote,
              onPressed: onQuote,
            ),
            _FormatToolButton(
              tooltip: strings.inlineCode,
              icon: Icons.code,
              onPressed: onInlineCode,
            ),
            _FormatToolButton(
              tooltip: strings.link,
              icon: Icons.link,
              onPressed: onLink,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatToolButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _FormatToolButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: selected ? scheme.primary : Colors.transparent,
          foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final Color color;

  const _ToolbarDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color,
    );
  }
}

class _AddVideoDialog extends StatefulWidget {
  final Note note;
  final String? token;

  const _AddVideoDialog({
    required this.note,
    required this.token,
  });

  @override
  State<_AddVideoDialog> createState() => _AddVideoDialogState();
}

class _AddVideoDialogState extends State<_AddVideoDialog> {
  final _urlController = TextEditingController();
  VideoPreview? _preview;
  String? _error;
  bool _loadingPreview = false;
  bool _adding = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = context.readStrings.pasteLink);
      return;
    }
    setState(() {
      _loadingPreview = true;
      _error = null;
      _preview = null;
    });

    try {
      final preview = await context.read<NotesProvider>().previewVideoUrl(
            url: url,
            token: widget.token,
          );
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _addVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = context.readStrings.pasteLink);
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });

    try {
      final video = await context.read<NotesProvider>().addVideoFromUrl(
            note: widget.note,
            url: url,
            token: widget.token,
          );
      if (!mounted) return;
      Navigator.pop(context, video);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final strings = context.strings;

    return AlertDialog(
      title: Text(strings.addVideo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: strings.videoLink,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadPreview(),
            ),
            const SizedBox(height: 12),
            if (_loadingPreview)
              const LinearProgressIndicator()
            else if (preview != null)
              _VideoPreviewPanel(preview: preview),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Colors.red[700]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _adding ? null : () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        TextButton.icon(
          onPressed: _loadingPreview || _adding ? null : _loadPreview,
          icon: const Icon(Icons.search),
          label: Text(strings.check),
        ),
        ElevatedButton.icon(
          onPressed: _loadingPreview || _adding ? null : _addVideo,
          icon: _adding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(strings.add),
        ),
      ],
    );
  }
}

class _VideoPreviewPanel extends StatelessWidget {
  final VideoPreview preview;

  const _VideoPreviewPanel({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            height: 58,
            child: _VideoThumbnail(thumbnailUrl: preview.thumbnailUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${preview.provider} · ${preview.mode}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                if (preview.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAttachmentTile extends StatelessWidget {
  final NoteVideo video;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _VideoAttachmentTile({
    required this.video,
    required this.onTap,
    required this.onDelete,
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
            _VideoThumbnail(thumbnailUrl: video.thumbnailPath),
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
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final String? thumbnailUrl;

  const _VideoThumbnail({this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl ?? '';
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _VideoPlaceholder(),
      );
    }
    return const _VideoPlaceholder();
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

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

class _ProtectionResult {
  final bool enabled;
  final String? password;

  const _ProtectionResult({
    required this.enabled,
    this.password,
  });
}

class _EditableImage {
  final String path;
  final XFile? file;

  const _EditableImage({
    required this.path,
    this.file,
  });
}

class _NoteProtectionDialog extends StatefulWidget {
  final bool isProtected;
  final String? initialPassword;

  const _NoteProtectionDialog({
    required this.isProtected,
    this.initialPassword,
  });

  @override
  State<_NoteProtectionDialog> createState() => _NoteProtectionDialogState();
}

class _NoteProtectionDialogState extends State<_NoteProtectionDialog> {
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmCtrl;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordCtrl = TextEditingController(text: widget.initialPassword ?? '');
    _confirmCtrl = TextEditingController(text: widget.initialPassword ?? '');
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final password = _passwordCtrl.text;
    if (password.length < 6) {
      setState(() => _errorText = context.readStrings.passwordMinSix);
      return;
    }
    if (password != _confirmCtrl.text) {
      setState(() => _errorText = context.readStrings.passwordsDoNotMatch);
      return;
    }
    Navigator.pop(
      context,
      _ProtectionResult(enabled: true, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.noteProtection),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: strings.password,
              errorText: _errorText,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: strings.confirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (widget.isProtected)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const _ProtectionResult(enabled: false),
            ),
            child: Text(
              strings.removeProtection,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(strings.save),
        ),
      ],
    );
  }
}

class _ProtectedNoteUnlockDialog extends StatefulWidget {
  const _ProtectedNoteUnlockDialog();

  @override
  State<_ProtectedNoteUnlockDialog> createState() =>
      _ProtectedNoteUnlockDialogState();
}

class _ProtectedNoteUnlockDialogState
    extends State<_ProtectedNoteUnlockDialog> {
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
          Text(context.strings.enterPasswordToEditNote),
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
