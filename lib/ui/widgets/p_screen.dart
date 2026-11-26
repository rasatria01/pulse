import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../strings.dart';
import '../tokens.dart';
import 'p_button.dart';

/// A full screen: background, safe area and a title row, with [child] below.
class PScreen extends StatelessWidget {
  const PScreen({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  /// Set on a pushed screen: shows a back button and keeps [child] above the
  /// keyboard.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: onBack == null
                ? 0
                : MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DefaultTextStyle(
            style: MelaText.body.copyWith(color: colors.foreground),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MelaSpace.s4,
                    vertical: MelaSpace.s2,
                  ),
                  child: Row(
                    spacing: MelaSpace.s2,
                    children: [
                      if (onBack != null)
                        PButton.ghost(
                          icon: LucideIcons.arrowLeft,
                          semanticLabel: MelaStrings.back,
                          onPressed: onBack,
                        ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: MelaText.titleLg.copyWith(
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
