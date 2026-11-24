import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/models/feedback_model.dart';
import 'package:smart_noties/providers/auth_provider.dart';
import 'package:smart_noties/providers/locale_provider.dart';
import 'package:smart_noties/screens/feedback_screen.dart';
import 'package:smart_noties/services/feedback_service.dart';

Map<String, dynamic> threadJson(
        {String status = 'new',
        List<Map<String, dynamic>> messages = const []}) =>
    {
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'category': 'bug',
      'subject': 'Save failed',
      'status': status,
      'platform': 'web',
      'locale': 'ru',
      'createdAt': '2026-11-24T12:00:00Z',
      'updatedAt': '2026-11-24T12:00:00Z',
      'unread': false,
      'preview': 'Steps',
      'messages': messages,
    };

class FakeFeedbackService extends FeedbackService {
  bool fail = false;
  final requests = <String>[];
  String? subject, body;
  bool repliedAsAdmin = false;
  FeedbackThread current = FeedbackThread.fromJson(threadJson());
  @override
  Future<FeedbackPage> list(
          {String? token,
          bool admin = false,
          String query = '',
          String status = '',
          String category = '',
          int offset = 0}) async =>
      FeedbackPage(items: [current], total: 1, unreadCount: 1);
  @override
  Future<FeedbackThread> create(
      {String? token,
      required String requestId,
      required String category,
      required String subject,
      required String body,
      String contactEmail = '',
      String locale = 'ru'}) async {
    requests.add(requestId);
    this.subject = subject;
    this.body = body;
    if (fail) throw const FeedbackException('feedback_unavailable');
    return current;
  }

  @override
  Future<FeedbackThread> read(String id,
          {String? token, bool admin = false}) async =>
      current;
  @override
  Future<FeedbackThread> reply(String id,
      {String? token,
      bool admin = false,
      required String requestId,
      required String body}) async {
    repliedAsAdmin = admin;
    current =
        FeedbackThread.fromJson(threadJson(status: 'in_progress', messages: [
      {
        'id': 'reply',
        'sender': 'admin',
        'body': body,
        'createdAt': '2026-11-24T12:01:00Z'
      }
    ]));
    return current;
  }

  @override
  Future<FeedbackThread> setStatus(String id, String status,
      {required String token}) async {
    final json = threadJson(
        status: status,
        messages: current.messages
            .map((m) => {
                  'id': m.id,
                  'sender': m.sender,
                  'body': m.body,
                  'createdAt': m.createdAt.toIso8601String()
                })
            .toList());
    current = FeedbackThread.fromJson(json);
    return current;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
      'Guest feedback credential survives restart, authenticated calls use JWT',
      () async {
    final credentials = <String?>[];
    final client = MockClient((request) async {
      credentials.add(request.headers['X-Feedback-Token']);
      return http.Response(
          jsonEncode({'items': [], 'total': 0, 'unreadCount': 0}), 200);
    });
    await FeedbackService(client: client).list();
    await FeedbackService(client: client).list();
    expect(credentials.first, hasLength(43));
    expect(credentials[1], credentials[0]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('feedback_guest_token'), credentials[0]);
    final signed = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer user-token');
      expect(request.headers.containsKey('X-Feedback-Token'), isFalse);
      return http.Response(
          jsonEncode({'items': [], 'total': 0, 'unreadCount': 0}), 200);
    });
    await FeedbackService(client: signed).list(token: 'user-token');
    client.close();
    signed.close();
  });
  test('Feedback reports canonical iOS platform and stable request ID',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final requestId = FeedbackService.newRequestId();
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['platform'], 'ios');
      expect(body['requestId'], requestId);
      return http.Response(jsonEncode(threadJson()), 201);
    });
    await FeedbackService(client: client).create(
        token: 'token',
        requestId: requestId,
        category: 'bug',
        subject: 'Save failed',
        body: 'Steps');
    client.close();
  });
  testWidgets('Failed feedback submission retains text and retry request ID',
      (tester) async {
    final service = FakeFeedbackService()..fail = true;
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider())
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    FeedbackComposeScreen(service: service))),
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('feedback-subject')), 'Ошибка сохранения');
    await tester.enterText(find.byKey(const ValueKey('feedback-body')),
        'Текст подробного описания');
    await tester.scrollUntilVisible(find.text('Отправить обращение'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Отправить обращение'));
    await tester.pumpAndSettle();
    expect(find.text('Ошибка сохранения'), findsOneWidget);
    expect(find.text('Текст подробного описания'), findsOneWidget);
    expect(find.textContaining('Обратная связь временно недоступна'),
        findsOneWidget);
    final input = tester
        .widget<TextFormField>(find.byKey(const ValueKey('feedback-body')))
        .controller!;
    input.selection = const TextSelection.collapsed(offset: 0);
    service.fail = false;
    await tester.scrollUntilVisible(find.text('Отправить обращение'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Отправить обращение'));
    await tester.pumpAndSettle();
    expect(service.requests, hasLength(2));
    expect(service.requests[0], service.requests[1]);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Admin can reply and resolve report without user profile providers',
      (tester) async {
    final service = FakeFeedbackService();
    await tester.pumpWidget(MaterialApp(
        home: FeedbackThreadScreen(
            id: service.current.id,
            admin: true,
            token: 'admin-token',
            service: service)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('feedback-reply')),
        'Исправили, проверьте обновление');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ответить'));
    await tester.tap(find.widgetWithText(FilledButton, 'Ответить'));
    await tester.pumpAndSettle();
    expect(service.repliedAsAdmin, isTrue);
    expect(service.current.status, 'in_progress');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Решено').last);
    await tester.pumpAndSettle();
    expect(service.current.status, 'resolved');
    expect(tester.takeException(), isNull);
  });
}
