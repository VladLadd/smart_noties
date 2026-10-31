import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Центрирует веб-интерфейс и ограничивает его ширину 1920 логическими px.
class WebMaxWidth extends StatelessWidget {
  final Widget child;

  const WebMaxWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1920),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}
