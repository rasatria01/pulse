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

  /// The current or next item: a turmeric time badge, at most one per screen.
  final bool now;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final due = start == null;
    final tabular = MelaText.amount.fontFeatures;
    final line = [
      if (!due) end == null ? start! : '$start\u2013$end',
      if (!due) ?duration,
      ?meta,
    ].join(' · ');

    Widget block = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: MelaSize.touch),
      padding: const EdgeInsets.symmetric(
        horizontal: MelaSpace.s3,
        vertical: MelaSpace.s2,
      ),
      decoration: due
          ? null
          : BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(MelaRadius.md),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MelaText.bodyStrong.copyWith(color: colors.foreground),
          ),
          if (line.isNotEmpty)
            Text(
              line,
              style: MelaText.caption.copyWith(
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
          radius: MelaRadius.md,
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
            horizontal: MelaSpace.s4,
            vertical: MelaSpace.s2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: MelaSpace.s3,
            children: [
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(48),
                child: Padding(
                  padding: const EdgeInsets.only(top: MelaSpace.s2),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: now
                          ? const EdgeInsets.symmetric(horizontal: MelaSpace.s1)
                          : null,
                      decoration: now
                          ? BoxDecoration(
                              color: colors.turmeric,
                              borderRadius: BorderRadius.circular(
                                MelaRadius.sm,
                              ),
                            )
                          : null,
                      child: Text(
                        start ?? MelaStrings.due,
                        style: MelaText.caption.copyWith(
                          color: now ? colors.onTurmeric : colors.inkSubtle,
                          fontFeatures: tabular,
                        ),
                      ),
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
