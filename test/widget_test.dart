import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/providers/auth_provider.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/providers/notes_provider.dart';
import 'package:smart_noties/screens/notes_grid_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSubject() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
      ],
      child: const MaterialApp(home: NotesGridScreen()),
    );
  }

  testWidgets('Проверка отображения элементов экрана заметок', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('У вас пока\nнет заметок'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(find.byIcon(Icons.view_list), findsOneWidget);
  });

  testWidgets('Переключение вида заметок не вызывает ошибку', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();

    expect(find.byIcon(Icons.grid_view), findsOneWidget);
  });
}
