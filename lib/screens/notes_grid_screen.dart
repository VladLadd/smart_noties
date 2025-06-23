import 'dart:io';

import 'package:flutter/material.dart';

import 'edit_note_screen.dart';

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
    final notes = [
      {
        'title': 'Купить',
        'subtitle': 'Помидоры, хлеб, сосиски,\nмайонез, молоко и яйца',
        'image': 'assets/images/watch.png',
      },
      {
        'title': 'Позвонить по налогам',
        'subtitle':
        'Может ли налоговая проводить рейды и контрольные закупки...',
        'image': 'assets/images/edward.png',
      },
      {
        'title': '',
        'subtitle': '',
        'image': 'assets/images/kitten.png',
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(8),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _buildImageTile('assets/images/dog.png'),
        _buildTextTile(notes[0]),
        _buildTextTile(notes[1]),
        _buildImageTile('assets/images/kitten.png'),
        _buildImageTile('assets/images/edward.png'),
        _buildImageTile('assets/images/watch.png'),
      ],
    );
  }

  Widget _buildImageTile(String imagePath) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditNoteScreen(initialImage: File(imagePath)),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Positioned(
            top: 8,
            left: 8,
            child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTile(Map<String, String> note) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EditNoteScreen(), // можно передать данные при необходимости
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note['title'] != null && note['title']!.isNotEmpty)
                  Text(
                    note['title']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                    ),
                  ),
                const SizedBox(height: 4),
                if (note['subtitle'] != null)
                  Text(
                    note['subtitle']!,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const Positioned(
            top: 8,
            left: 8,
            child: Icon(Icons.play_arrow, color: Colors.black, size: 28),
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
        children: const [
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
            _fabAction(Icons.videocam, 'Видео', () {}),
            const SizedBox(height: 12),
            _fabAction(Icons.camera_alt, 'Камера', () {}),
            const SizedBox(height: 12),
            _fabAction(Icons.mic, 'Голос', () {}),
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