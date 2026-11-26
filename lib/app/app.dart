import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../core/routes.dart';
import '../features/settings/controllers/settings_providers.dart';
import '../ui/theme.dart';
import 'di.dart';
import 'router.dart';

class PulseApp extends ConsumerStatefulWidget {
  const PulseApp({super.key, this.themeMode});

  /// Overrides the stored 'theme' setting; for tests.
  final ShadThemeMode? themeMode;

  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp> {
  late final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // The restart after a restore lands on Settings, which says how it went.
    if (ref.read(restoreResultProvider) == null) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _router.push(Routes.settings),
    );
  }

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
    themeMode:
        widget.themeMode ??
        ref.watch(themeModeProvider).value ??
        ShadThemeMode.system,
    routerConfig: _router,
    // The chosen theme may differ from the system's: match the bar icons.
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: ShadTheme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: child!,
    ),
  );
}
