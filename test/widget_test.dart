import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_noties/screens/notes_grid_screen.dart';

void main() {
  testWidgets('Проверка отображения элементов сетки заметок', (WidgetTester tester) async {
    // Отображаем экран
    await tester.pumpWidget(const MaterialApp(home: NotesGridScreen()));

    // Проверяем наличие кнопки "+"
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Проверяем наличие заголовка "Купить"
    expect(find.text('Купить'), findsOneWidget);

    // Проверяем наличие текста "Помидоры, хлеб..."
    expect(find.textContaining('Помидоры'), findsOneWidget);

    // Проверка иконки play (можно уточнить, если нужны только белые/чёрные)
    expect(find.byIcon(Icons.play_arrow), findsWidgets);

    // Проверка нижней кнопки "КОРЗИНА"
    expect(find.text('КОРЗИНА'), findsOneWidget);

    // Проверка нижней иконки сетки
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
  });

  testWidgets('Нажатие на FloatingActionButton не вызывает ошибку', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotesGridScreen()));

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pump(); // обновление UI

    // Если сюда дошли — ошибки нет
    expect(true, isTrue);
  });
}