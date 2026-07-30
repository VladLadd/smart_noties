import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'note_edit_screen.dart';
import 'note_view_screen.dart';
import 'profile_screen.dart';
import '../providers/notes_provider.dart';
import '../providers/auth_provider.dart';
import '../models/note_model.dart';

class NotesGridScreen extends StatefulWidget {
  const NotesGridScreen({super.key});

  @override
  State<NotesGridScreen> createState() => _NotesGridScreenState();
}

class _NotesGridScreenState extends State<NotesGridScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildGrid()),
                _buildBottomBar(),
              ],
            ),
            _buildFabMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final notes = context.watch<NotesProvider>().notes;

    return GridView.builder(
      itemCount: notes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final note = notes[index];
        return InkWell(
          onTap: () => _openNote(note),
          onLongPress: () => _showNoteActions(note),
          child: _buildNoteTile(note),
        );
      },
    );
  }

  Future<void> _openNote(Note note) async {
    if (note.hasProtection) {
      final password = await _showProtectedNoteDialog();
      if (password == null) return;

      try {
        await context.read<NotesProvider>().verifyNotePassword(
              note,
              password: password,
              token: context.read<AuthProvider>().token,
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red[700]),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteViewScreen(
          note: note,
          initiallyUnlocked: note.hasProtection,
        ),
      ),
    );
  }

  Future<String?> _showProtectedNoteDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _ProtectedNotePasswordDialog(),
    );
  }

  void _showNoteActions(Note note) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteEditScreen(initialNote: note),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Удалить',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteDialog(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text(
          note.title.isNotEmpty ? '«${note.title}»' : 'Заметка будет удалена.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<NotesProvider>();
              final token = context.read<AuthProvider>().token;
              Navigator.pop(ctx);
              provider.deleteNote(note.id, token: token).catchError((e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$e'),
                    backgroundColor: Colors.red[700],
                  ),
                );
              });
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(Note note) {
    ImageProvider? imageProvider;
    if (!note.hasProtection && note.imagePath != null) {
      imageProvider = note.imagePath!.startsWith('assets/')
          ? AssetImage(note.imagePath!) as ImageProvider
          : FileImage(File(note.imagePath!));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: note.color.withOpacity(0.85),
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          if (note.hasProtection)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Защищённая\nзаметка',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (note.hasProtection)
            Positioned(
              top: 0,
              right: note.isPending ? 24 : 0,
              child: const Tooltip(
                message: 'Защищённая заметка',
                child: Icon(Icons.lock, size: 18),
              ),
            ),
          if (!note.hasProtection && note.title.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          if (note.isPending)
            const Positioned(
              top: 0,
              right: 0,
              child: Tooltip(
                message: 'Не отправлено на сервер',
                child: Icon(Icons.cloud_off, size: 18, color: Colors.orange),
              ),
            ),
          if (!note.hasProtection && note.isVoice)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomNavButton(
            label: 'ПРОФИЛЬ',
            icon: Icons.person,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const Icon(Icons.circle, size: 24),
          const Icon(Icons.grid_view, size: 24),
        ],
      ),
    );
  }

  Widget _buildFabMenu() {
    return Positioned(
      bottom: 60,
      right: 24,
      child: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteEditScreen()),
        ),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _BottomNavButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ProtectedNotePasswordDialog extends StatefulWidget {
  const _ProtectedNotePasswordDialog();

  @override
  State<_ProtectedNotePasswordDialog> createState() =>
      _ProtectedNotePasswordDialogState();
}

class _ProtectedNotePasswordDialogState
    extends State<_ProtectedNotePasswordDialog> {
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
          const Text('Для чтения этой заметки введите пароль.'),
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
