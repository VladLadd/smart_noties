import 'dart:async';

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        defaultTargetPlatform,
        kIsWeb,
        LicenseRegistry,
        LicenseEntryWithLineBreaks;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'providers/locale_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/incoming_share_provider.dart';
import 'screens/notes_grid_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/web_max_width.dart';
import 'widgets/first_launch_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Hershey Text JS'],
        await rootBundle.loadString('assets/licenses/hersheytext.txt'));
  });
  runApp(const SmartNotesApp());
}

class SmartNotesApp extends StatelessWidget {
  const SmartNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: false),
        ChangeNotifierProvider(create: (_) => NotesProvider(), lazy: false),
        ChangeNotifierProvider(
            create: (_) => IncomingShareProvider(), lazy: false),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'Smart Notes',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('ru'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            builder: (context, child) => WebMaxWidth(
              child: child ?? const SizedBox.shrink(),
            ),
            home: const FirstLaunchGate(
                child: _FaceDownHiddenNotesLock(
              child: _HomeRouter(),
            )),
          );
        },
      ),
    );
  }
}

class _FaceDownHiddenNotesLock extends StatefulWidget {
  final Widget child;

  const _FaceDownHiddenNotesLock({required this.child});

  @override
  State<_FaceDownHiddenNotesLock> createState() =>
      _FaceDownHiddenNotesLockState();
}

class _FaceDownHiddenNotesLockState extends State<_FaceDownHiddenNotesLock> {
  static const _faceDownZThreshold = -7.0;
  static const _flatAxisTolerance = 4.0;
  static const _holdDuration = Duration(milliseconds: 700);

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  Timer? _faceDownHoldTimer;
  bool _locking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldWatch = _supportsMotionWatch &&
        Provider.of<NotesProvider>(context).isHiddenNotesVisible;
    _setMotionWatchEnabled(shouldWatch);
  }

  bool get _supportsMotionWatch {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    if (!_isFaceDown(event)) {
      _clearFaceDownTimer();
      return;
    }

    _faceDownHoldTimer ??= Timer(
      _holdDuration,
      () => unawaited(_hideHiddenNotesBecauseFaceDown()),
    );
  }

  bool _isFaceDown(AccelerometerEvent event) {
    return event.z < _faceDownZThreshold &&
        event.x.abs() < _flatAxisTolerance &&
        event.y.abs() < _flatAxisTolerance;
  }

  void _clearFaceDownTimer() {
    _faceDownHoldTimer?.cancel();
    _faceDownHoldTimer = null;
  }

  void _setMotionWatchEnabled(bool enabled) {
    if (!enabled) {
      _clearFaceDownTimer();
      final subscription = _accelerometerSub;
      _accelerometerSub = null;
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
      return;
    }
    if (_accelerometerSub != null) return;

    try {
      _accelerometerSub = accelerometerEvents.listen(
        _handleAccelerometerEvent,
        onError: (_) => _setMotionWatchEnabled(false),
        cancelOnError: true,
      );
    } catch (_) {
      _setMotionWatchEnabled(false);
    }
  }

  Future<void> _hideHiddenNotesBecauseFaceDown() async {
    _faceDownHoldTimer = null;
    if (!mounted || _locking) return;

    final notesProvider = context.read<NotesProvider>();
    if (!notesProvider.isHiddenNotesVisible) return;

    _locking = true;
    final token = context.read<AuthProvider>().token;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    navigator.popUntil((route) => route.isFirst);
    try {
      await notesProvider.lockHiddenNotes(token: token);
      if (!mounted) return;
      _setMotionWatchEnabled(false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.readStrings.faceDownHidden),
        ),
      );
    } finally {
      _locking = false;
    }
  }

  @override
  void dispose() {
    _clearFaceDownTimer();
    _accelerometerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _HomeRouter extends StatefulWidget {
  const _HomeRouter();

  @override
  State<_HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<_HomeRouter> {
  bool _openingShare = false;

  void _openPendingShareWhenReady() {
    if (_openingShare) return;
    final incoming = context.read<IncomingShareProvider>().pending;
    final auth = context.read<AuthProvider>();
    final notes = context.read<NotesProvider>();
    if (incoming == null ||
        (auth.status != AuthStatus.authenticated && !auth.isGuest)) {
      return;
    }

    _openingShare = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final share = context.read<IncomingShareProvider>().takePending();
      if (share == null) {
        _openingShare = false;
        return;
      }
      try {
        await notes.importShare(share);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.readStrings.sharedNoteSaved)));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.readStrings.errorMessage(error)),
              action: SnackBarAction(
                  label: context.readStrings.retry,
                  onPressed: () =>
                      context.read<IncomingShareProvider>().retry(share))));
        }
      } finally {
        if (mounted) setState(() => _openingShare = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<IncomingShareProvider>().pending;
    final authStatus = context.watch<AuthProvider>().status;

    if (authStatus == AuthStatus.checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authStatus == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    final auth = context.watch<AuthProvider>();
    final notesProvider = context.watch<NotesProvider>();
    final token = auth.token;
    if (notesProvider.isGuestMode != auth.isGuest) {
      unawaited(
          Future.microtask(() => notesProvider.setGuestMode(auth.isGuest)));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (notesProvider.guestLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.isGuest && notesProvider.guestLoadError != null) {
      return Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(context.strings.guestStorageError),
        TextButton(
            onPressed: () => notesProvider.setGuestMode(true),
            child: Text(context.strings.retry)),
        TextButton(
            onPressed: () => auth.logout(),
            child: Text(context.strings.guestSignIn)),
      ])));
    }

    _openPendingShareWhenReady();
    if (notesProvider.shouldLoadServerNotes(token)) {
      unawaited(
        Future.microtask(
          () => notesProvider.loadServerNotes(token: token),
        ),
      );
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (notesProvider.loadingServerNotes && notesProvider.notes.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const NotesGridScreen();
  }
}
