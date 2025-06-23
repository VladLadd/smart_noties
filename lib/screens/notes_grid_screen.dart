import 'package:flutter/material.dart';

import 'add_note_screen.dart';
import 'edit_note_screen.dart';
import '../data/note_data.dart';
import '../models/note_model.dart';

class NotesGridScreen extends StatefulWidget {
  const NotesGridScreen({super.key});

  @override
  State<NotesGridScreen> createState() => _NotesGridScreenState();
}

class _NotesGridScreenState extends State<NotesGridScreen> {
  bool isMenuOpen = false;

  void toggleMenu() {
    setState(() {
      isMenuOpen = !isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7F6),
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
    final List<Note> notesToShow = notes;

    return GridView.builder(
      itemCount: notesToShow.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final note = notesToShow[index];
        return InkWell(
          onTap: () async {
            final updatedNote = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditNoteScreen(note: note),
              ),
            );

            if (updatedNote != null) {
              setState(() {
                notes[index] = updatedNote;
              });
            }
          },
          child: _buildNoteTile(note),
        );
      },
    );
  }
  Widget _buildNoteTile(Note note) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withOpacity(0.6),
        image: note.imagePath != null
            ? DecorationImage(
          image: AssetImage(note.imagePath!),
          fit: BoxFit.cover,
        )
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
          Icon(Icons.circle, size: 24), // placeholder
          Icon(Icons.grid_view, size: 24),
        ],
      ),
    );
  }

  Widget _buildFabMenu() {
    return Positioned(
      bottom: 60,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMenuOpen) ...[
            _fabAction(Icons.videocam, 'Видео', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddNoteScreen()),
              );
            }),
            const SizedBox(height: 12),
            _fabAction(Icons.camera_alt, 'Камера', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddNoteScreen()),
              );
            }),
            const SizedBox(height: 12),
            _fabAction(Icons.mic, 'Голос', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddNoteScreen()),
              );
            }),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            onPressed: toggleMenu,
            backgroundColor: Colors.black,
            shape: const CircleBorder(),
            elevation: 6,
            child: Icon(
              isMenuOpen ? Icons.close : Icons.add,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fabAction(IconData icon, String label, VoidCallback onTap) {
    return FloatingActionButton(
      heroTag: label,
      mini: true,
      onPressed: onTap,
      backgroundColor: Colors.black,
      child: Icon(icon, color: Colors.white),
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
      icon: Icon(icon, color: Colors.black),
      label: Text(label, style: const TextStyle(color: Colors.black)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}