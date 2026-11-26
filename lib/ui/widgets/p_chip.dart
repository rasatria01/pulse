import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../identity.dart';
import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';
import 'common.dart';

/// neutral = parsed; placeholder = not found yet; error = blocks Save.
enum PChipTone { neutral, placeholder, positive, warning, error }

/// A pill showing one parsed value; tapping opens that field's picker.
class PChip extends StatelessWidget {
  const PChip({
    super.key,
    required this.label,
    this.field,
    this.tone = PChipTone.neutral,
    this.icon,
    this.dotColor,
    this.numeric = false,
    this.selected = false,
    this.onPressed,
  });

  final String label;

  /// Read by TalkBack as "field: label".
  final String? field;
  final PChipTone tone;
  final IconData? icon;

  /// Stored wallet or category ARGB colour, shown as a dot.
  final int? dotColor;

  /// Tabular figures, for amounts.
  final bool numeric;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final clear = colors.background.withValues(alpha: 0);
    final (background, foreground) = selected
        ? (colors.primary, colors.primaryForeground)
        : switch (tone) {
            PChipTone.neutral => (colors.secondary, colors.foreground),
            PChipTone.placeholder => (clear, colors.inkSubtle),
            PChipTone.positive => (colors.positiveSoft, colors.positive),
            PChipTone.warning => (colors.warningSoft, colors.warning),
            PChipTone.error => (colors.dangerSoft, colors.destructive),
          };
    final radius = BorderRadius.circular(MelaRadius.full);
    final leadingIcon =
        icon ?? (tone == PChipTone.error ? LucideIcons.circleAlert : null);

    Widget chip = ShadButton.raw(
      variant: ShadButtonVariant.ghost,
      onPressed: onPressed,
      height: scaledControlHeight(context, MelaSize.controlSm),
      padding: const EdgeInsets.symmetric(horizontal: MelaSpace.s3),
      gap: MelaSpace.s1,
      backgroundColor: background,
      hoverBackgroundColor: background,
      pressedBackgroundColor: background == clear ? colors.accent : background,
      foregroundColor: foreground,
      hoverForegroundColor: foreground,
      pressedForegroundColor: foreground,
      textStyle: numeric
          ? MelaText.label.copyWith(fontFeatures: MelaText.amount.fontFeatures)
          : MelaText.label,
      decoration: ShadDecoration(
        border: ShadBorder.all(width: 0, radius: radius),
        secondaryFocusedBorder: ShadBorder.all(
          width: 2,
          color: colors.ring,
          radius: radius,
          offset: 2,
        ),
      ),
      leading: dotColor == null && leadingIcon == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: MelaSpace.s1,
              children: [
                if (dotColor != null)
                  Container(
                    width: MelaSpace.s2,
                    height: MelaSpace.s2,
                    decoration: BoxDecoration(
                      color: identityColor(dotColor!),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (leadingIcon != null)
                  Icon(leadingIcon, size: MelaSize.iconSm),
              ],
            ),
      child: Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
    if (tone == PChipTone.placeholder && !selected) {
      chip = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: colors.input,
          radius: MelaRadius.full,
        ),
        child: chip,
      );
    }

    final suffix = tone == PChipTone.error ? ' (${MelaStrings.error})' : '';
    return PTapTarget(
      label: '${field == null ? '' : '$field: '}$label$suffix',
      onTap: onPressed,
      selected: selected ? true : null,
      child: chip,
    );
  }
}

/// A row of chips or pills that scrolls sideways instead of wrapping.
class PChipRow extends StatelessWidget {
  const PChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(spacing: MelaSpace.s2, children: children),
  );
}
