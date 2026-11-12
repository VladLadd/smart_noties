import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/locale_provider.dart';
import 'handwritten_wordmark.dart';

const welcomeCompletedKey = 'welcome_completed_v1';

class FirstLaunchGate extends StatefulWidget {
  final Widget child;
  const FirstLaunchGate({super.key, required this.child});
  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  bool? _completed;
  bool _finishing = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var completed = false;
    try {
      completed = (await SharedPreferences.getInstance())
              .getBool(welcomeCompletedKey) ??
          false;
    } catch (_) {/* Недоступное хранилище браузера не блокирует запуск. */}
    if (mounted) setState(() => _completed = completed);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await (await SharedPreferences.getInstance())
          .setBool(welcomeCompletedKey, true);
    } catch (_) {/* В этом сеансе всё равно открываем приложение. */}
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) => _completed == true
      ? widget.child
      : WelcomeScreen(
          animate: _completed == false,
          onFinished: _finish,
        );
}

class WelcomeScreen extends StatefulWidget {
  final bool animate;
  final VoidCallback onFinished;
  const WelcomeScreen(
      {super.key, required this.animate, required this.onFinished});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _reduceMotion = false;
  Timer? _staticTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4400))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _start();
  }

  @override
  void didUpdateWidget(covariant WelcomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _start();
  }

  void _start() {
    if (_started || !widget.animate) return;
    _started = true;
    if (_reduceMotion) {
      _staticTimer =
          Timer(const Duration(milliseconds: 800), widget.onFinished);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _staticTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Scaffold(
        body: DecoratedBox(
      decoration: BoxDecoration(
          gradient: RadialGradient(
        center: const Alignment(0, -0.18),
        radius: 0.85,
        colors: [
          Color.alphaBlend(
              const Color(0xFF7561FF).withValues(alpha: dark ? 0.10 : 0.05),
              Theme.of(context).scaffoldBackgroundColor),
          Theme.of(context).scaffoldBackgroundColor
        ],
      )),
      child: SafeArea(
          child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final value = _reduceMotion ? 0.85 : _controller.value;
                final writing =
                    const Interval(0.14, 0.82, curve: Curves.easeInOutSine)
                        .transform(value);
                final leaving = _reduceMotion
                    ? 1.0
                    : 1 - const Interval(0.94, 1).transform(value);
                return Opacity(
                    opacity: leaving,
                    child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight),
                                  child: Center(
                                    child: Padding(
                                        padding: const EdgeInsets.all(28),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 480),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              28),
                                                      boxShadow: [
                                                        BoxShadow(
                                                            color: const Color(
                                                                    0xFF7863FF)
                                                                .withValues(
                                                                    alpha: dark
                                                                        ? 0.16
                                                                        : 0.09),
                                                            blurRadius: 48,
                                                            spreadRadius: 4),
                                                      ]),
                                                  child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              28),
                                                      child: Image.asset(
                                                        dark
                                                            ? 'assets/icons/app_icon_dark.png'
                                                            : 'assets/icons/app_icon_light.png',
                                                        width: 128,
                                                        height: 128,
                                                        excludeFromSemantics:
                                                            true,
                                                      )),
                                                ),
                                                const SizedBox(height: 40),
                                                HandwrittenWordmark(
                                                    progress: writing,
                                                    startColor: dark
                                                        ? const Color(
                                                            0xFFA8E7FF)
                                                        : const Color(
                                                            0xFF3099DE),
                                                    endColor: dark
                                                        ? const Color(
                                                            0xFFB58AFF)
                                                        : const Color(
                                                            0xFF8752E8)),
                                                const SizedBox(height: 18),
                                                Opacity(
                                                    opacity: _reduceMotion
                                                        ? 1
                                                        : const Interval(
                                                                0.76, 0.90)
                                                            .transform(value),
                                                    child: Text(
                                                      context.strings
                                                          .firstLaunchWelcome,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.copyWith(
                                                              color: scheme
                                                                  .onSurfaceVariant,
                                                              letterSpacing:
                                                                  0.5),
                                                    )),
                                              ]),
                                        )),
                                  )),
                            )));
              })),
    ));
  }
}
