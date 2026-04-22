import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'note_edit_screen.dart';
import '../providers/notes_provider.dart';
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(initialNote: note),
            ),
          ),
          onLongPress: () => _showDeleteDialog(note),
          child: _buildNoteTile(note),
        );
      },
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
              context.read<NotesProvider>().deleteNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(Note note) {
    ImageProvider? imageProvider;
    if (note.imagePath != null) {
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
      child: note.title.isNotEmpty
          ? Column(
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
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildBottomBar() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomNavButton(label: 'КОРЗИНА', icon: Icons.shopping_cart),
          Icon(Icons.circle, size: 24),
          Icon(Icons.grid_view, size: 24),
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

  const _BottomNavButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
