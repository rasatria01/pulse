import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../identity.dart';
import '../tokens.dart';
import 'amount_text.dart';
import 'common.dart';
import 'p_icon.dart';

/// One wallet: icon in its identity colour, name and balance.
class PWalletPill extends StatelessWidget {
  const PWalletPill({
    super.key,
    required this.name,
    required this.color,
    this.icon = 'wallet',
    this.balance,
    this.selected = false,
    this.onPressed,
  });

  final String name;

  /// Stored ARGB colour.
  final int color;

  /// Stored icon name.
  final String icon;
  final Rupiah? balance;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final radius = BorderRadius.circular(PulseRadius.full);
    return PTapTarget(
      label: balance == null
          ? name
          : '$name, ${amountLabel(balance!, AmountType.balance)}',
      onTap: onPressed,
      selected: selected ? true : null,
      child: ShadButton.raw(
        variant: ShadButtonVariant.ghost,
        onPressed: onPressed,
        height: scaledControlHeight(context, PulseSize.controlSm),
        padding: const EdgeInsets.only(
          left: PulseSpace.s2,
          right: PulseSpace.s3,
        ),
        gap: PulseSpace.s2,
        backgroundColor: colors.secondary,
        hoverBackgroundColor: colors.secondary,
        pressedBackgroundColor: colors.accent,
        foregroundColor: colors.foreground,
        hoverForegroundColor: colors.foreground,
        pressedForegroundColor: colors.foreground,
        decoration: ShadDecoration(
          border: ShadBorder.all(
            width: 1,
            color: selected ? colors.foreground : colors.secondary,
            radius: radius,
          ),
          secondaryFocusedBorder: ShadBorder.all(
            width: 2,
            color: colors.ring,
            radius: radius,
            offset: 2,
          ),
        ),
        leading: Icon(
          pulseIcon(icon, fallback: LucideIcons.wallet),
          size: PulseSize.iconSm,
          color: identityColor(color),
        ),
        trailing: balance == null
            ? null
            : AmountText(
                balance!,
                type: AmountType.balance,
                size: AmountSize.sm,
              ),
        child: Text(
          name,
          maxLines: 1,
          style: PulseText.label.copyWith(color: colors.mutedForeground),
        ),
      ),
    );
  }
}
