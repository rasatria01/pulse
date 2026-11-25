import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../theme.dart';
import '../tokens.dart';
import 'common.dart';

/// Opens a [PSheet]. Swipe down or a tap on the scrim closes it and the future
/// completes with null.
Future<T?> showPSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final still = reduceMotion(context);
  List<ShadAnimEffect<dynamic>> slide(
    Offset begin,
    Offset end,
    Duration duration,
  ) => [
    SlideEffect(
      begin: begin,
      end: end,
      duration: still ? const Duration(milliseconds: 1) : duration,
      curve: ShadSheet.defaultAnimationCurve,
    ),
  ];
  return showShadSheet<T>(
    context: context,
    side: ShadSheetSide.bottom,
    barrierColor: ShadTheme.of(context).colorScheme.scrim,
    animateIn: slide(
      const Offset(0, 1),
      Offset.zero,
      ShadSheet.defaultEnterDuration,
    ),
    animateOut: slide(
      Offset.zero,
      const Offset(0, 1),
      ShadSheet.defaultExitDuration,
    ),
    builder: builder,
  );
}

/// The bottom sheet body: handle, title, content and a right-aligned footer
/// (an optional ghost button, then one primary). Show it with [showPSheet].
class PSheet extends StatelessWidget {
  const PSheet({
    super.key,
    this.title,
    required this.child,
    this.footer = const [],
  });

  final String? title;
  final Widget child;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    return ShadSheet(
      draggable: true,
      isScrollControlled: true,
      closeIcon: const SizedBox.shrink(),
      backgroundColor: colors.surfaceRaised,
      radius: const BorderRadius.vertical(
        top: Radius.circular(PulseRadius.xl2),
      ),
      removeBorderRadiusWhenTiny: false,
      border: const Border(),
      shadows: PulseShadow.sheet(theme.brightness),
      padding: const EdgeInsets.fromLTRB(
        PulseSpace.s4,
        PulseSpace.s2,
        PulseSpace.s4,
        PulseSpace.s4,
      ),
      gap: PulseSpace.s3,
      actionsAxis: Axis.vertical,
      expandActionsWhenTiny: false,
      actions: [
        if (footer.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: PulseSpace.s3,
              children: footer,
            ),
          ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PulseSpace.s3,
        children: [
          Center(
            child: Container(
              width: 36,
              height: PulseSpace.s1,
              decoration: BoxDecoration(
                color: colors.input,
                borderRadius: BorderRadius.circular(PulseRadius.full),
              ),
            ),
          ),
          if (title != null)
            Semantics(
              header: true,
              namesRoute: true,
              child: Text(
                title!,
                style: PulseText.title.copyWith(color: colors.foreground),
              ),
            ),
          DefaultTextStyle(
            style: PulseText.body.copyWith(color: colors.foreground),
            child: child,
          ),
        ],
      ),
    );
  }
}
