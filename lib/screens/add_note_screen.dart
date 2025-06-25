import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/note_model.dart';
import '../data/note_data.dart';
import '../widgets/color_picker_menu.dart';

Color selectedColor = Colors.white;

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen>
    with SingleTickerProviderStateMixin {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();

  File? imageFile;
  bool isRecording = false;
  String? recordedPath;
  int recordSeconds = 0;
  Timer? _timer;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _recorder.openRecorder();
    _player.openPlayer();
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked =
    await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> startOrStopRecording() async {
    if (!isRecording) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;

      final tempDir = Directory.systemTemp;
      final path = '${tempDir.path}/note_voice.aac';

      await _recorder.startRecorder(toFile: path);
      setState(() {
        isRecording = true;
        recordedPath = path;
        recordSeconds = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          recordSeconds += 1;
        });
      });
    } else {
      await _recorder.stopRecorder();
      _timer?.cancel();
      setState(() {
        isRecording = false;
      });
    }
  }

  Future<void> playRecording() async {
    if (recordedPath != null) {
      await _player.startPlayer(fromURI: recordedPath);
    }
  }

  void _saveNote() {
    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: titleController.text,
      body: bodyController.text,
      imagePath: imageFile?.path,
      isVoice: recordedPath != null,
    );

    notes.insert(0, note); // добавляем в начало списка
    Navigator.pop(context); // возвращаемся к списку
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7F6),
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя панель
            Padding(
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
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: ColorPickerMenu(
                            selectedColor: selectedColor,
                            onColorSelected: (color) {
                              setState(() {
                                selectedColor = color;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.grid_view),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Фото
            Container(
              margin: const EdgeInsets.all(16),
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
                image: imageFile != null
                    ? DecorationImage(
                  image: FileImage(imageFile!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: imageFile == null
                  ? const Center(child: Text('Нет изображения'))
                  : null,
            ),

            // Текстовые поля
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
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
                    controller: bodyController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Введите текст заметки...',
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            if (recordedPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  children: [
                    Text(
                      isRecording
                          ? 'Запись... ${recordSeconds}s'
                          : 'Голосовая заметка сохранена',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (!isRecording)
                      TextButton.icon(
                        onPressed: playRecording,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Прослушать'),
                      ),
                  ],
                ),
              ),

            const Spacer(),

            // Кнопки
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _saveButton(),
                  Row(
                    children: [
                      _animatedIcon(Icons.mic, delay: 0, onTap: startOrStopRecording),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return ElevatedButton(
      onPressed: _saveNote,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: const Text(
        'СОХРАНИТЬ',
        style: TextStyle(color: Colors.white),
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