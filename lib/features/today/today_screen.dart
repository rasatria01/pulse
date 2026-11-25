import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../ui/tokens.dart';

/// Empty shell; sections arrive with their milestones.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(PulseSpace.s4),
            child: Semantics(
              header: true,
              child: Text(
                'Today',
                style: PulseText.titleLg.copyWith(color: colors.foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
