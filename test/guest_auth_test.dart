import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_noties/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
      'Guest mode persists on mobile and can be left without losing its storage',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await auth.enterGuestMode();
    expect(auth.isGuest, isTrue);
    expect(auth.token, isNull);
    expect(auth.userId, isNull);
    auth.dispose();
    final restored = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    expect(restored.isGuest, isTrue);
    await restored.logout();
    expect(restored.status, AuthStatus.unauthenticated);
    expect(
        (await SharedPreferences.getInstance()).getBool('guest_mode'), isNull);
    restored.dispose();
  });
  test('Guest mode is unavailable on desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({'guest_mode': true});
    final auth = AuthProvider();
    await Future<void>.delayed(Duration.zero);
    await auth.enterGuestMode();
    expect(AuthProvider.supportsGuestMode, isFalse);
    expect(auth.isGuest, isFalse);
    auth.dispose();
  });
}
