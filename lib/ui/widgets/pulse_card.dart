import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../strings.dart';
import '../tokens.dart';
import 'amount_text.dart';
import 'common.dart';
import 'p_chip.dart';
import 'p_wallet_pill.dart';

/// The Financial pulse card. A null [safeToSpend] omits the headline and bar.
class PulseCard extends StatelessWidget {
  const PulseCard({
    super.key,
    required this.liquid,
    this.safeToSpend,
    this.todaySpend = Rupiah.zero,
    this.wallets = const [],
    this.showBudgetHint = false,
  });

  /// Balances of wallets included in the total and not archived.
  final Rupiah liquid;

  /// The day's allowance, computed once at the start of the day.
  final Rupiah? safeToSpend;

  /// OUTCOME with occurred_on = today, transfers excluded.
  final Rupiah todaySpend;
  final List<PWalletPill> wallets;

  /// With no [safeToSpend], say that setting a budget shows it.
  final bool showBudgetHint;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final muted = PulseText.caption.copyWith(
      color: colors.mutedForeground,
      fontFeatures: PulseText.amount.fontFeatures,
    );
    final safe = safeToSpend;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: PulseStrings.financialPulse,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PulseSpace.s4),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(PulseRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PulseSpace.s3,
          children: [
            if (safe != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: PulseSpace.s1,
                children: [
                  Text(
                    PulseStrings.safeToSpend,
                    style: PulseText.captionStrong.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  AmountText(
                    safe,
                    type: AmountType.balance,
                    size: AmountSize.hero,
                  ),
                ],
              ),
              PSpendBar(
                spent: todaySpend.value,
                limit: safe.value,
                semanticLabel: PulseStrings.spentToday,
              ),
              _spread([
                Text(
                  PulseStrings.spent(formatRupiah(todaySpend)),
                  style: muted,
                ),
                _remaining(context, safe, muted),
              ]),
            ] else if (showBudgetHint) ...[
              Text(PulseStrings.setBudget, style: muted),
              _spread([
                Text(PulseStrings.spentToday, style: muted),
                AmountText(
                  todaySpend,
                  type: AmountType.balance,
                  size: AmountSize.sm,
                ),
              ]),
            ],
            _spread([
              Text(PulseStrings.liquidBalance, style: muted),
              AmountText(liquid, type: AmountType.balance, size: AmountSize.sm),
            ]),
            if (wallets.isNotEmpty)
              Container(
                padding: const EdgeInsets.only(top: PulseSpace.s1),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: PulseStrings.wallets,
                  child: PChipRow(children: wallets),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _spread(List<Widget> children) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: PulseSpace.s3,
    children: children,
  );

  Widget _remaining(BuildContext context, Rupiah safe, TextStyle muted) {
    final left = safe - todaySpend;
    final level = SpendLevel.of(todaySpend.value, safe.value);
    final color = level.statusColor(ShadTheme.of(context).colorScheme);
    return Text(
      left.value < 0
          ? PulseStrings.overBy(formatRupiah(left))
          : PulseStrings.left(formatRupiah(left)),
      style: color == null
          ? muted
          : muted.copyWith(
              color: color,
              fontWeight: PulseText.captionStrong.fontWeight,
              fontVariations: PulseText.captionStrong.fontVariations,
            ),
    );
  }
}
