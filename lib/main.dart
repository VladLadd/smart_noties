import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/notes_provider.dart';
import 'screens/start_screen.dart';
import 'screens/notes_grid_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SmartNotesApp());
}

class SmartNotesApp extends StatelessWidget {
  const SmartNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotesProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _HomeRouter(),
      ),
    );
  }
}

class _HomeRouter extends StatelessWidget {
  const _HomeRouter();

  @override
  Widget build(BuildContext context) {
    final hasNotes = context.watch<NotesProvider>().notes.isNotEmpty;
    return hasNotes ? const NotesGridScreen() : const StartScreen();
  }
}
