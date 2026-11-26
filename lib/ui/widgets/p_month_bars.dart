import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../theme.dart';
import '../tokens.dart';

/// One month of [PMonthBars].
typedef MonthBar = ({
  String label,

  /// What a screen reader says for the month, with both values.
  String semanticLabel,
  int income,
  int spent,
});

/// Paired income and spending bars, one pair per month, on one scale. The last
/// month is the picked one.
class PMonthBars extends StatelessWidget {
  const PMonthBars({super.key, required this.months});

  final List<MonthBar> months;

  static const double _height = 120;
  static const double _bar = 12;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final top = months.fold(
      0,
      (m, e) => math.max(m, math.max(e.income, e.spent)),
    );

    Widget bar(int value, Color color) => Container(
      width: _bar,
      // A ratio for drawing only; the money itself stays int. A value above
      // zero is at least 2px, so it never reads as none.
      height: value <= 0 ? 0 : math.max(2, _height * value / top),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, month) in months.indexed)
          Expanded(
            child: Semantics(
              container: true,
              label: month.semanticLabel,
              excludeSemantics: true,
              child: Column(
                spacing: MelaSpace.s1,
                children: [
                  Container(
                    height: _height,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 2,
                      children: [
                        bar(month.income, colors.positive),
                        bar(month.spent, colors.foreground),
                      ],
                    ),
                  ),
                  Text(
                    month.label,
                    maxLines: 1,
                    softWrap: false,
                    style:
                        (i == months.length - 1
                                ? MelaText.captionStrong
                                : MelaText.caption)
                            .copyWith(
                              color: i == months.length - 1
                                  ? colors.foreground
                                  : colors.mutedForeground,
                            ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
