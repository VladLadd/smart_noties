import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/models/note_model.dart';
import 'package:smart_noties/models/note_location.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/services/guest_notes_store.dart';
import 'package:smart_noties/services/note_client_crypto.dart';
import 'package:smart_noties/widgets/note_location_card.dart';

class DeniedLocation extends GeolocatorPlatform {
  bool positionRequested = false;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    positionRequested = true;
    throw StateError('Нельзя запрашивать координаты без разрешения');
  }
}

class AllowedLocation extends DeniedLocation {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      Position(
          latitude: 55.75,
          longitude: 37.61,
          timestamp: DateTime(2026),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0);
}

void main() {
  const location =
      NoteLocation(latitude: 55.75, longitude: 37.61, label: 'Место');
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Widget app(Widget child) => ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(home: Scaffold(body: child)));

  test('Location round trip, old notes, removal and malformed coordinates', () {
    final note =
        Note(id: '1', title: 'Note', body: '', locationData: location.encode());
    expect(Note.fromJson(note.toJson()).location!.longitude, 37.61);
    expect(note.copyWith(clearLocationData: true).location, isNull);
    expect(
        Note.fromJson({'id': 'old', 'title': '', 'body': ''}).location, isNull);
    expect(NoteLocation.decode('{"latitude":91,"longitude":0}'), isNull);
    expect(NoteLocation.decode('cenc:v1:secret'), isNull);
    expect(
        () => const NoteLocation(latitude: double.nan, longitude: 0).encode(),
        throwsFormatException);
  });

  test(
      'Protected local location survives restart without storing coordinates in clear text',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('location-crypto-test-');
    try {
      final store = GuestNotesStore(directoryProvider: () async => directory);
      final prepared = await store.prepare(Note(
          id: 'guest_1',
          title: 'Private',
          body: '',
          isProtected: true,
          protectionPassword: 'test-password',
          locationData: location.encode()));
      await store.write([prepared]);
      final raw =
          await File('${directory.path}/guest_notes/notes.json').readAsString();
      expect(raw, isNot(contains('55.75')));
      expect(raw, isNot(contains('test-password')));
      final loaded = (await store.load()).single;
      expect(loaded.location, isNull);
      final opened = await decryptNoteFromClient(loaded, 'test-password');
      expect(opened.location!.label, 'Место');
      expect(opened.location!.latitude, 55.75);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  testWidgets('Manual entry validates ranges and accepts decimal comma',
      (tester) async {
    NoteLocation? selected;
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              selected = await editNoteLocation(context, null);
            },
            child: const Text('Add')))));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('location-latitude')), '91');
    await tester.enterText(
        find.byKey(const ValueKey('location-longitude')), '37,61');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Введите широту от −90 до 90'), findsOneWidget);
    expect(selected, isNull);
    await tester.enterText(
        find.byKey(const ValueKey('location-latitude')), '55,75');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(selected!.latitude, 55.75);
    expect(selected!.longitude, 37.61);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Denied location permission keeps manual entry available',
      (tester) async {
    final previous = GeolocatorPlatform.instance;
    final denied = DeniedLocation();
    GeolocatorPlatform.instance = denied;
    addTearDown(() => GeolocatorPlatform.instance = previous);
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () => editNoteLocation(context, null),
            child: const Text('Add')))));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Моё местоположение'));
    await tester.pumpAndSettle();
    expect(denied.positionRequested, isFalse);
    expect(find.textContaining('Разрешите доступ'), findsOneWidget);
    expect(find.byKey(const ValueKey('location-latitude')), findsOneWidget);
  });

  testWidgets(
      'Picker lists installed maps and launches the selected app with correct coordinates',
      (tester) async {
    const channel = MethodChannel('map_launcher');
    MethodCall? launched;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'getInstalledMaps') {
        return [
          {'mapName': 'Google Maps', 'mapType': 'google'},
          {'mapName': 'Яндекс Карты', 'mapType': 'yandexMaps'},
        ];
      }
      if (call.method == 'showMarker') launched = call;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(app(const NoteLocationCard(location: location)));
    await tester.tap(find.text('Место'));
    await tester.pumpAndSettle();
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Яндекс Карты'), findsOneWidget);
    expect(find.text('Открыть карту в браузере'), findsOneWidget);
    await tester.tap(find.text('Яндекс Карты'));
    await tester.pumpAndSettle();
    expect(launched!.arguments['mapType'], 'yandexMaps');
    expect(launched!.arguments['latitude'], '55.75');
    expect(launched!.arguments['longitude'], '37.61');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Current position fills fields and can be saved', (tester) async {
    final previous = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = AllowedLocation();
    addTearDown(() => GeolocatorPlatform.instance = previous);
    NoteLocation? result;
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              result = await editNoteLocation(context, null);
            },
            child: const Text('Add')))));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Моё местоположение'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(result!.latitude, 55.75);
    expect(result!.longitude, 37.61);
  });

  testWidgets('Map discovery failure still offers browser', (tester) async {
    const channel = MethodChannel('map_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel, (_) async => throw PlatformException(code: 'unavailable'));
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(app(const NoteLocationCard(location: location)));
    await tester.tap(find.text('Место'));
    await tester.pumpAndSettle();
    expect(find.text('Открыть карту в браузере'), findsOneWidget);
  });
}
