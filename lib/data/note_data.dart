import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/note_model.dart';

final List<Note> notes = [
  Note(
    id: '1',
    title: 'Купить',
    body: 'Помидоры, хлеб, сосиски, майонез, молоко и яйца',
    imagePath: 'assets/images/kitten.png',
  ),
  Note(
    id: '2',
    title: 'Позвонить по налогам',
    body: 'Может ли налоговая проводить рейды и как себя вести...',
    imagePath: 'assets/images/edward.png',
  )
];

final List<Color> noteColors = [
  Colors.white,
  const Color(0xFFD0EAF8),
  const Color(0xFFF5EDD9),
  const Color(0xFFFFB494),
  const Color(0xFF99D9B1),
  const Color(0xFF7A7C87),
];