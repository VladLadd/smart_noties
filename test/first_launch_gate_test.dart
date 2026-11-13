import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/theme/app_theme.dart';
import 'package:smart_noties/widgets/first_launch_gate.dart';
import 'package:smart_noties/widgets/handwritten_wordmark.dart';

Widget subject({bool reducedMotion = false, Widget? home}) =>
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: home ??
                  const FirstLaunchGate(child: Text('Application ready')))),
    );

void main() {
  testWidgets(
      'First launch writes the welcome flag only after animation finishes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(subject());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool(welcomeCompletedKey),
        isNull);
    await tester.pump(const Duration(seconds: 2));
    final progress = tester
        .widget<HandwrittenWordmark>(find.byType(HandwrittenWordmark))
        .progress;
    expect(progress, greaterThan(0));
    expect(progress, lessThan(1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Application ready'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool(welcomeCompletedKey),
        isTrue);
  });
  testWidgets('Subsequent launches skip the welcome animation', (tester) async {
    SharedPreferences.setMockInitialValues({welcomeCompletedKey: true});
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.text('Application ready'), findsOneWidget);
  });
  testWidgets('Reduced motion shows a static greeting and completes quickly',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(subject(reducedMotion: true));
    await tester.pump();
    expect(
        tester
            .widget<HandwrittenWordmark>(find.byType(HandwrittenWordmark))
            .progress,
        1);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('Application ready'), findsOneWidget);
  });
  testWidgets('Greeting fits a phone screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final capture = GlobalKey();
    await tester.pumpWidget(subject(
        reducedMotion: true,
        home: RepaintBoundary(
            key: capture,
            child: WelcomeScreen(animate: false, onFinished: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Добро пожаловать'), findsNothing);
    expect(find.byType(HandwrittenWordmark), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Platform.environment['SMART_NOTES_CAPTURE_WELCOME'] == '1') {
      await tester.runAsync(() async {
        final boundary = capture.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/smart-notes-welcome.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
