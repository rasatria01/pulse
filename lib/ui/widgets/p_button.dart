import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../tokens.dart';
import 'common.dart';

enum PButtonSize { md, sm }

/// The app's only button: `ShadButton` with Pulse's variants and sizes.
/// A null [onPressed] disables it.
class PButton extends StatelessWidget {
  const PButton.primary({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.size = PButtonSize.md,
    this.block = false,
    this.semanticLabel,
  }) : variant = ShadButtonVariant.primary,
       assert(label != null || semanticLabel != null);

  const PButton.secondary({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.size = PButtonSize.md,
    this.block = false,
    this.semanticLabel,
  }) : variant = ShadButtonVariant.secondary,
       assert(label != null || semanticLabel != null);

  const PButton.outline({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.size = PButtonSize.md,
    this.block = false,
    this.semanticLabel,
  }) : variant = ShadButtonVariant.outline,
       assert(label != null || semanticLabel != null);

  const PButton.ghost({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.size = PButtonSize.md,
    this.block = false,
    this.semanticLabel,
  }) : variant = ShadButtonVariant.ghost,
       assert(label != null || semanticLabel != null);

  /// Only inside a confirmation step, never as the first tap.
  const PButton.destructive({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.size = PButtonSize.md,
    this.block = false,
    this.semanticLabel,
  }) : variant = ShadButtonVariant.destructive,
       assert(label != null || semanticLabel != null);

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final PButtonSize size;
  final bool block;

  /// Required for an icon-only button.
  final String? semanticLabel;
  final ShadButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final small = size == PButtonSize.sm;
    final height = scaledControlHeight(
      context,
      small ? PulseSize.controlSm : PulseSize.control,
    );
    final clear = colors.background.withValues(alpha: 0);
    final (background, foreground, pressed) = switch (variant) {
      ShadButtonVariant.primary => (
        colors.primary,
        colors.primaryForeground,
        colors.primary,
      ),
      ShadButtonVariant.destructive => (
        colors.destructive,
        colors.destructiveForeground,
        colors.destructive,
      ),
      ShadButtonVariant.secondary => (
        colors.secondary,
        colors.secondaryForeground,
        colors.accent,
      ),
      _ => (clear, colors.foreground, colors.accent),
    };
    final iconOnly = label == null;

    return PTapTarget(
      label: semanticLabel ?? label!,
      onTap: onPressed,
      disabled: onPressed == null,
      child: ShadButton.raw(
        variant: variant,
        enabled: onPressed != null,
        onPressed: onPressed,
        width: block ? double.infinity : (iconOnly ? height : null),
        height: height,
        padding: iconOnly
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(
                horizontal: small ? PulseSpace.s3 : PulseSpace.s4,
              ),
        gap: PulseSpace.s2,
        backgroundColor: background,
        hoverBackgroundColor: background,
        pressedBackgroundColor: pressed,
        foregroundColor: foreground,
        hoverForegroundColor: foreground,
        pressedForegroundColor: foreground,
        textStyle: PulseText.label,
        pressAnimationDuration: reduceMotion(context) ? Duration.zero : null,
        decoration: variant == ShadButtonVariant.outline
            ? ShadDecoration(
                border: ShadBorder.all(
                  color: colors.input,
                  width: 1,
                  radius: BorderRadius.circular(PulseRadius.md),
                ),
              )
            : null,
        leading: icon == null
            ? null
            : Icon(icon, size: small ? PulseSize.iconSm : PulseSize.icon),
        child: iconOnly
            ? null
            : Flexible(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
      ),
    );
  }
}
