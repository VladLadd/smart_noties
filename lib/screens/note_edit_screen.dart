import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/note_model.dart';
import '../providers/notes_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_config.dart';
import '../widgets/color_picker_menu.dart';
import '../widgets/voice_message_player.dart';

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
  late Color _selectedColor;

  File? _imageFile;
  String? _assetImagePath; // отдельно храним оригинальный asset-путь
  bool _isRecording = false;
  String? _recordedPath;
  int _recordSeconds = 0;
  int _recordedDuration = 0; // длительность завершённой записи, сек
  Timer? _timer;
  bool _isProtected = false;
  String? _protectionPassword;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late AnimationController _animController;
  late AnimationController _pulseController;

  bool _saving = false;
  bool _syncing = false;
  bool _isLocked = false;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;

    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _selectedColor = note?.color ?? Colors.white;
    _isProtected = note?.hasProtection ?? false;
    _protectionPassword = note?.protectionPassword;
    _isLocked = _isProtected && !widget.initiallyUnlocked;

    if (note?.imagePath != null) {
      if (note!.imagePath!.startsWith('assets/')) {
        _assetImagePath = note.imagePath;
      } else {
        _imageFile = File(note.imagePath!);
      }
    }
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
    _recorder.closeRecorder();
    _animController.dispose();
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _hasImage => _imageFile != null || _assetImagePath != null;

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
      await context.read<NotesProvider>().verifyNotePassword(
            note,
            password: password,
            token: context.read<AuthProvider>().token,
          );
      if (!mounted) return;
      setState(() => _isLocked = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  Future<void> _onColorSelected(Color color) async {
    if (_hasImage) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Заменить картинку?'),
          content: const Text(
            'Выбранный цвет заменит текущее изображение заметки.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Заменить',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() {
        _imageFile = null;
        _assetImagePath = null;
      });
    }
    setState(() => _selectedColor = color);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нужен доступ к микрофону для записи'),
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
        const SnackBar(content: Text('Необходима авторизация для отправки')),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      await context.read<NotesProvider>().syncNote(
        widget.initialNote!,
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
    final imagePath = _imageFile?.path ?? _assetImagePath;

    try {
      // Свежую локальную запись заливаем на сервер → в заметке будет URL.
      String? voicePath = _recordedPath;
      if (voicePath != null &&
          !isRemoteMedia(voicePath) &&
          auth.token != null &&
          auth.token!.isNotEmpty) {
        final file = File(voicePath);
        if (await file.exists()) {
          try {
            voicePath = await provider.uploadVoice(file, auth.token!);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Голос не загружен, сохранён локально'),
                  backgroundColor: Colors.orange[800],
                ),
              );
            }
            // оставляем локальный путь — заметка сохранится, голос локальный
          }
        }
      }

      if (_isEditing) {
        final updated = widget.initialNote!.copyWith(
          title: _titleController.text,
          body: _bodyController.text,
          imagePath: imagePath,
          clearImagePath: imagePath == null,
          voicePath: voicePath,
          clearVoicePath: voicePath == null,
          isVoice: voicePath != null,
          color: _selectedColor,
          isProtected: _isProtected,
          protectionPassword: _protectionPassword,
          clearProtectionPassword: !_isProtected,
        );
        provider.updateNote(updated);
      } else {
        await provider.addNote(
          Note(
            id: '',
            title: _titleController.text,
            body: _bodyController.text,
            imagePath: imagePath,
            voicePath: voicePath,
            isVoice: voicePath != null,
            color: _selectedColor,
            isProtected: _isProtected,
            protectionPassword: _isProtected ? _protectionPassword : null,
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

  @override
  Widget build(BuildContext context) {
    if (_isLocked) return _buildLockedScreen();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(),
            _buildImagePreview(),
            _buildTextFields(),
            _buildVoiceSection(),
            const Spacer(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedScreen() {
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
              const Text(
                'Защищённая заметка',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Введите пароль, чтобы читать и редактировать заметку.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestUnlock,
                icon: const Icon(Icons.lock_open),
                label: const Text('Ввести пароль'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
              if (_isEditing && widget.initialNote!.isPending) ...[
                _syncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                        tooltip: 'Отправить на сервер',
                        onPressed: _syncNote,
                      ),
                const SizedBox(width: 8),
              ],
              ColorPickerMenu(
                selectedColor: _selectedColor,
                onColorSelected: _onColorSelected,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_isProtected ? Icons.lock : Icons.lock_open),
                tooltip: _isProtected ? 'Изменить защиту' : 'Защитить заметку',
                onPressed: _showProtectionDialog,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.grid_view),
            ],
          ),
        ],
      ),
    );
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
              widget.initialNote!,
              isProtected: result.enabled,
              password: result.password,
              token: context.read<AuthProvider>().token,
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Защита включена локально. Перезапустите backend для сохранения на сервере.',
            ),
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

  Widget _buildImagePreview() {
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (_assetImagePath != null) {
      imageProvider = AssetImage(_assetImagePath!);
    }

    return Container(
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
      child: imageProvider == null
          ? const Center(child: Text('Нет изображения'))
          : null,
    );
  }

  Widget _buildTextFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
            decoration: const InputDecoration(
              hintText: 'Заголовок...',
              border: InputBorder.none,
            ),
          ),
          TextField(
            controller: _bodyController,
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Введите текст заметки...',
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSection() {
    if (_isRecording) return _buildRecordingPanel();
    if (_recordedPath != null) {
      return VoiceMessagePlayer(
        key: ValueKey(_recordedPath),
        path: _recordedPath!,
        token: context.read<AuthProvider>().token,
        initialDuration: _recordedDuration > 0
            ? Duration(seconds: _recordedDuration)
            : null,
        onDelete: _deleteRecording,
      );
    }
    return const SizedBox.shrink();
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
            'Запись  ${_fmt(Duration(seconds: _recordSeconds))}',
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
            label: const Text('Стоп', style: TextStyle(color: Colors.red)),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
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
                : const Text('СОХРАНИТЬ'),
          ),
          Row(
            children: [
              _animatedIcon(
                _isRecording ? Icons.stop : Icons.mic,
                delay: 0,
                onTap: _toggleRecording,
                background: _isRecording ? Colors.red : Colors.black,
              ),
              const SizedBox(width: 16),
              _animatedIcon(Icons.camera_alt, delay: 100,
                  onTap: () => _pickImage(ImageSource.camera)),
              const SizedBox(width: 16),
              _animatedIcon(Icons.videocam, delay: 200,
                  onTap: () => _pickImage(ImageSource.gallery)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _animatedIcon(IconData icon,
      {required int delay, VoidCallback? onTap, Color background = Colors.black}) {
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
}

class _ProtectionResult {
  final bool enabled;
  final String? password;

  const _ProtectionResult({
    required this.enabled,
    this.password,
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
      setState(() => _errorText = 'Пароль должен быть не короче 6 символов');
      return;
    }
    if (password != _confirmCtrl.text) {
      setState(() => _errorText = 'Пароли не совпадают');
      return;
    }
    Navigator.pop(
      context,
      _ProtectionResult(enabled: true, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Защита заметки'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Пароль',
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
              labelText: 'Подтвердите пароль',
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
            child: const Text(
              'Снять защиту',
              style: TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Сохранить'),
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

class _ProtectedNoteUnlockDialogState extends State<_ProtectedNoteUnlockDialog> {
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
      title: const Text('Защищённая заметка'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Для редактирования этой заметки введите пароль.'),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Пароль',
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
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _passwordCtrl.text),
          child: const Text('Открыть'),
        ),
      ],
    );
  }
}
