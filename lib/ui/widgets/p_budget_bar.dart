import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../identity.dart';
import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';
import 'amount_text.dart';
import 'common.dart';
import 'p_icon.dart';

/// One outcome category's month: spent against cap, said in words.
class PBudgetBar extends StatelessWidget {
  const PBudgetBar({
    super.key,
    required this.category,
    required this.color,
    required this.spent,
    required this.cap,
    this.icon = 'tag',
    this.onPressed,
  });

  final String category;

  /// Stored ARGB colour.
  final int color;

  /// Stored icon name.
  final String icon;
  final Rupiah spent;

  /// Greater than zero; a category with no cap has no bar.
  final Rupiah cap;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final level = SpendLevel.of(spent.value, cap.value);
    final percent = cap.value <= 0 ? 0 : spent.value * 100 ~/ cap.value;
    final status = spent.value > cap.value
        ? PulseStrings.overBy(formatRupiah(spent - cap))
        : PulseStrings.percentUsed(percent);
    final remaining = level == SpendLevel.critical
        ? PulseStrings.capReached
        : PulseStrings.left(formatRupiah(cap - spent));
    final tabular = PulseText.amount.fontFeatures;

    Widget spread(List<Widget> children) => SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: PulseSpace.s2,
        children: children,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        container: true,
        button: onPressed != null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PulseSize.touch),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: PulseSpace.s3,
            children: [
              PIconTile(icon: pulseIcon(icon), color: identityColor(color)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: PulseSpace.s2,
                  children: [
                    spread([
                      Text(
                        category,
                        style: PulseText.bodyStrong.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        '${formatRupiah(spent)} / ${formatRupiah(cap)}',
                        style: PulseText.amountSm.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ]),
                    PSpendBar(
                      spent: spent.value,
                      limit: cap.value,
                      semanticLabel: PulseStrings.budgetOf(category),
                    ),
                    spread([
                      Text(
                        status,
                        style: PulseText.captionStrong.copyWith(
                          color:
                              level.statusColor(colors) ??
                              colors.mutedForeground,
                          fontFeatures: tabular,
                        ),
                      ),
                      Text(
                        remaining,
                        style: PulseText.caption.copyWith(
                          color: colors.inkSubtle,
                          fontFeatures: tabular,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
