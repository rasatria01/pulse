import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../../domain/entities/transaction.dart';
import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';

enum AmountType {
  outcome,
  income,
  transfer,
  balance;

  static AmountType of(TxnType type) => switch (type) {
    TxnType.outcome => outcome,
    TxnType.income => income,
    TxnType.transfer => transfer,
  };
}

enum AmountSize { hero, lg, md, sm }

final _digits = NumberFormat.decimalPattern('id_ID');

/// `Rp` + no-break space + dot-grouped digits, without a sign.
String formatRupiah(Rupiah value) =>
    'Rp\u00a0${_digits.format(value.value.abs())}';

/// What [AmountText] shows: U+2212 for expenses and negative balances, `+` for
/// income, no sign for transfers.
String formatAmount(Rupiah value, AmountType type) {
  final sign = switch (type) {
    AmountType.outcome => '\u2212',
    AmountType.income => '+',
    AmountType.transfer => '',
    AmountType.balance => value.value < 0 ? '\u2212' : '',
  };
  return '$sign${formatRupiah(value)}';
}

/// The screen-reader form, such as "Expense Rp 35.000".
String amountLabel(Rupiah value, AmountType type) {
  final word = switch (type) {
    AmountType.outcome => PulseStrings.expense,
    AmountType.income => PulseStrings.income,
    AmountType.transfer => PulseStrings.transfer,
    AmountType.balance => PulseStrings.balance,
  };
  final minus = type == AmountType.balance && value.value < 0
      ? '${PulseStrings.minus} '
      : '';
  return '$word $minus${formatRupiah(value).replaceAll('\u00a0', ' ')}';
}

/// An amount at the end of a row: a very long one shrinks, whole, instead of
/// pushing the title out of the row.
class TrailingAmount extends StatelessWidget {
  const TrailingAmount({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * 0.4,
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: child,
    ),
  );
}

/// Every money value in Pulse. [value] is a magnitude except for a balance,
/// which may be negative.
class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.type = AmountType.outcome,
    this.size = AmountSize.md,
  });

  final Rupiah value;
  final AmountType type;
  final AmountSize size;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final style = switch (size) {
      AmountSize.hero => PulseText.amountHero,
      AmountSize.lg => PulseText.amountLg,
      AmountSize.md => PulseText.amount,
      AmountSize.sm => PulseText.amountSm,
    };
    return Text(
      formatAmount(value, type),
      semanticsLabel: amountLabel(value, type),
      // The hero may wrap but never shrinks; the rest stay on one line.
      softWrap: size == AmountSize.hero,
      style: style.copyWith(
        color: switch (type) {
          AmountType.income => colors.positive,
          AmountType.transfer => colors.mutedForeground,
          AmountType.outcome || AmountType.balance => colors.foreground,
        },
      ),
    );
  }
}
