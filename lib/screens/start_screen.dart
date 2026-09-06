import 'package:flutter/material.dart';
import '../providers/locale_provider.dart';
import 'note_edit_screen.dart';
import 'profile_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          strings.noNotesTitle,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Georgia',
                            height: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.profile,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.person_outline, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    strings.noNotesSubtitle,
                    style: TextStyle(
                      fontSize: 18,
                      color: scheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              bottom: 130,
              right: 28,
              child: Icon(Icons.arrow_downward, size: 48),
            ),
            Positioned(
              bottom: 60,
              right: 24,
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NoteEditScreen(),
                  ),
                ),
                child: const Icon(Icons.add, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
