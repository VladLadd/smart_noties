import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/providers/auth_provider.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/providers/notes_provider.dart';
import 'package:smart_noties/screens/notes_grid_screen.dart';

class _Notes extends NotesProvider {
  @override
  List<Note> get notes => [
        Note(
            id: 'manual',
            title: 'Manual note',
            body: 'local text',
            createdAt: DateTime.now()),
        Note(
            id: 'incoming',
            title: 'Received link',
            body: 'shared text',
            isIncoming: true,
            createdAt: DateTime.now()),
      ];
}

void main() {
  testWidgets('Incoming tab and keyword search filter the visible cards',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<NotesProvider>(create: (_) => _Notes()),
    ], child: const MaterialApp(home: NotesGridScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Manual note'), findsOneWidget);
    await tester.tap(find.text('Входящие'));
    await tester.pumpAndSettle();
    expect(find.text('Manual note'), findsNothing);
    expect(find.text('Received link'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Received link'), findsNothing);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Received link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
