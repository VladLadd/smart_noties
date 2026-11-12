import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notes_provider.dart';
import 'faq_screen.dart';

class GuestProfileScreen extends StatelessWidget {
  const GuestProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.profile)),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.phone_android, size: 64),
        const SizedBox(height: 16),
        Text(strings.guestModeTitle,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(strings.guestModeDescription),
        const SizedBox(height: 20),
        ListTile(
            leading: const Icon(Icons.notes),
            title: Text(strings.notesCount),
            trailing: Text('${context.watch<NotesProvider>().notes.length}')),
        DropdownButtonFormField<AppLanguage>(
          initialValue: context.watch<LocaleProvider>().language,
          decoration: InputDecoration(labelText: strings.languageLabel),
          items: [
            DropdownMenuItem(
                value: AppLanguage.ru, child: Text(strings.russian)),
            DropdownMenuItem(
                value: AppLanguage.en, child: Text(strings.english))
          ],
          onChanged: (language) {
            if (language != null) {
              context.read<LocaleProvider>().setLanguage(language);
            }
          },
        ),
        const SizedBox(height: 16),
        ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(strings.faqTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FaqScreen()))),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Text(strings.guestSignIn)),
      ]),
    );
  }
}
