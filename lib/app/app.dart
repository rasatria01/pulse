import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../ui/theme.dart';
import 'router.dart';

class PulseApp extends StatefulWidget {
  const PulseApp({super.key, this.themeMode = ShadThemeMode.system});

  // The settings thread drives this from app_settings 'theme'.
  final ShadThemeMode themeMode;

  @override
  State<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends State<PulseApp> {
  late final _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadApp.router(
    title: 'Pulse',
    theme: pulseTheme(Brightness.light),
    darkTheme: pulseTheme(Brightness.dark),
    themeMode: widget.themeMode,
    routerConfig: _router,
  );
}
