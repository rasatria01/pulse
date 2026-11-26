// Pieces shared by the ui/ widgets.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../theme.dart';
import '../tokens.dart';

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [base] height, grown when the scaled label line would not fit in it.
double scaledControlHeight(BuildContext context, double base) => math.max(
  base,
  MediaQuery.textScalerOf(context).scale(MelaText.label.fontSize!) *
          MelaText.label.height! +
      MelaSpace.s2,
);

/// A hit area of at least 48x48 around a smaller control, read by TalkBack as
/// one node with [label].
class PTapTarget extends StatelessWidget {
  const PTapTarget({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
    this.checked,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool? selected;

  /// Non-null makes the node a checkbox rather than a button.
  final bool? checked;

  /// Announces the control as disabled. A null [onTap] alone does not.
  final bool disabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTap = disabled ? null : this.onTap;
    return Semantics(
      container: true,
      button: checked == null && (onTap != null || disabled),
      enabled: disabled ? false : (onTap == null ? null : true),
      selected: selected,
      checked: checked,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: MelaSize.touch,
            minHeight: MelaSize.touch,
          ),
          child: Align(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// The round `fill` tile behind a row's icon.
class PIconTile extends StatelessWidget {
  const PIconTile({super.key, required this.icon, this.color});

  final IconData icon;

  /// An identity colour, only when the icon stands for a wallet or category.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return Container(
      width: MelaSize.tile,
      height: MelaSize.tile,
      decoration: BoxDecoration(color: colors.muted, shape: BoxShape.circle),
      child: Icon(
        icon,
        size: MelaSize.icon,
        color: color ?? colors.mutedForeground,
      ),
    );
  }
}

/// How close spending is to its limit.
enum SpendLevel {
  ok,
  warning,
  critical;

  /// 80% warns, 100% is critical. Integer math: no floating point for money.
  static SpendLevel of(int spent, int limit) {
    if (limit <= 0) return spent > 0 ? critical : ok;
    if (spent >= limit) return critical;
    return spent * 100 >= limit * 80 ? warning : ok;
  }

  /// The colour of a status word; null keeps the caller's neutral colour.
  Color? statusColor(ShadColorScheme colors) => switch (this) {
    ok => null,
    warning => colors.warning,
    critical => colors.destructive,
  };
}

/// The 6px spend bar. The words next to it carry the state.
class PSpendBar extends StatelessWidget {
  const PSpendBar({
    super.key,
    required this.spent,
    required this.limit,
    required this.semanticLabel,
  });

  final int spent;
  final int limit;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    // A ratio for drawing only; the money itself stays int.
    final value = limit <= 0
        ? (spent > 0 ? 1.0 : 0.0)
        : (spent / limit).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(MelaRadius.full);
    return ShadProgress(
      value: value,
      minHeight: 6,
      color:
          SpendLevel.of(spent, limit).statusColor(colors) ?? colors.foreground,
      backgroundColor: colors.muted,
      borderRadius: radius,
      innerBorderRadius: radius,
      semanticsLabel: semanticLabel,
      semanticsValue: '${(value * 100).floor()}%',
    );
  }
}

/// A dashed outline: placeholder chips and the Due lane.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(math.min(radius, size.shortestSide / 2)),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
