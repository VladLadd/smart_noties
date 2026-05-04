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
import '../widgets/color_picker_menu.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? initialNote;

  const NoteEditScreen({super.key, this.initialNote});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late Color _selectedColor;

  File? _imageFile;
  String? _assetImagePath; // отдельно храним оригинальный asset-путь
  bool _isRecording = false;
  String? _recordedPath;
  int _recordSeconds = 0;
  Timer? _timer;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  late AnimationController _animController;

  bool _saving = false;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;

    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _selectedColor = note?.color ?? Colors.white;

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

    _recorder.openRecorder();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _animController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _hasImage => _imageFile != null || _assetImagePath != null;

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
      if (!status.isGranted) return;

      final path = '${Directory.systemTemp.path}/note_voice_${widget.initialNote?.id ?? 'new'}.aac';
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
      setState(() => _isRecording = false);
    }
  }

  Future<void> _playRecording() async {
    if (_recordedPath != null) {
      await _player.startPlayer(fromURI: _recordedPath);
    }
  }

  Future<void> _saveNote() async {
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<NotesProvider>();
    final auth = context.read<AuthProvider>();
    final imagePath = _imageFile?.path ?? _assetImagePath;

    try {
      if (_isEditing) {
        final updated = widget.initialNote!.copyWith(
          title: _titleController.text,
          body: _bodyController.text,
          imagePath: imagePath,
          clearImagePath: imagePath == null,
          voicePath: _recordedPath,
          clearVoicePath: _recordedPath == null,
          isVoice: _recordedPath != null,
          color: _selectedColor,
        );
        provider.updateNote(updated);
      } else {
        final userId = auth.userId ?? 0;
        final token = auth.token ?? '';
        await provider.addNote(
          Note(
            id: '',
            title: _titleController.text,
            body: _bodyController.text,
            imagePath: imagePath,
            voicePath: _recordedPath,
            isVoice: _recordedPath != null,
            color: _selectedColor,
          ),
          userId: userId,
          token: token,
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(),
            _buildImagePreview(),
            _buildTextFields(),
            if (_recordedPath != null) _buildVoiceStatus(),
            const Spacer(),
            _buildBottomActions(),
          ],
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
              ColorPickerMenu(
                selectedColor: _selectedColor,
                onColorSelected: _onColorSelected,
              ),
              const SizedBox(width: 16),
              const Icon(Icons.grid_view),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildVoiceStatus() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Text(
            _isRecording
                ? 'Запись... ${_recordSeconds}s'
                : 'Голосовая заметка сохранена',
            style: const TextStyle(color: Colors.grey),
          ),
          if (!_isRecording)
            TextButton.icon(
              onPressed: _playRecording,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Прослушать'),
            ),
        ],
      ),
    );
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
              _animatedIcon(Icons.mic, delay: 0, onTap: _toggleRecording),
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
      {required int delay, VoidCallback? onTap}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Interval(delay / 300, 1.0, curve: Curves.easeOut),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
