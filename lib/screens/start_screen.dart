import 'package:flutter/material.dart';

import 'notes_grid_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7F6),
      body: SafeArea(
        child: Stack(
          children: [
            // Основной текст
            Padding(
              padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'У вас пока\nнет заметок',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Georgia', // подключи кастомный при желании
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Нажмите на плюсик,\nчтобы создать первую',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Стрелка
            Positioned(
              bottom: 140,
              right: 36,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.black,
                  ),
                  const Icon(Icons.arrow_downward, size: 24, color: Colors.black),
                ],
              ),
            ),

            // Плюс-кнопка
            Positioned(
              bottom: 60,
              right: 24,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotesGridScreen()),
                  );
                },
                backgroundColor: Colors.black,
                shape: const CircleBorder(),
                elevation: 6,
                child: const Icon(Icons.add, size: 32, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}