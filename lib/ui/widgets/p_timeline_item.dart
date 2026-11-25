import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';
import 'common.dart';

/// One timeline or agenda row. A null [start] puts it in the Due lane.
class PTimelineItem extends StatelessWidget {
  const PTimelineItem({
    super.key,
    required this.title,
    this.start,
    this.end,
    this.duration,
    this.meta,
    this.now = false,
    this.onPressed,
  });

  final String title;

  /// Local 'HH:mm'.
  final String? start;
  final String? end;

  /// Already formatted, such as "30 min".
  final String? duration;

  /// Tags, reminder offset.
  final String? meta;

  /// The current item: its time label turns ink.
  final bool now;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final due = start == null;
    final tabular = PulseText.amount.fontFeatures;
    final line = [
      if (!due) end == null ? start! : '$start\u2013$end',
      if (!due) ?duration,
      ?meta,
    ].join(' · ');

    Widget block = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: PulseSize.touch),
      padding: const EdgeInsets.symmetric(
        horizontal: PulseSpace.s3,
        vertical: PulseSpace.s2,
      ),
      decoration: due
          ? null
          : BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(PulseRadius.md),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PulseText.bodyStrong.copyWith(color: colors.foreground),
          ),
          if (line.isNotEmpty)
            Text(
              line,
              style: PulseText.caption.copyWith(
                color: colors.mutedForeground,
                fontFeatures: tabular,
              ),
            ),
        ],
      ),
    );
    if (due) {
      block = CustomPaint(
        painter: DashedBorderPainter(
          color: colors.input,
          radius: PulseRadius.md,
        ),
        child: block,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        container: true,
        button: onPressed != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PulseSpace.s4,
            vertical: PulseSpace.s2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: PulseSpace.s3,
            children: [
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(44),
                child: Padding(
                  padding: const EdgeInsets.only(top: PulseSpace.s2),
                  child: Text(
                    start ?? PulseStrings.due,
                    style: PulseText.caption.copyWith(
                      color: now ? colors.foreground : colors.inkSubtle,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ),
              Expanded(child: block),
            ],
          ),
        ),
      ),
    );
  }
}
