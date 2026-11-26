import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/local_date.dart';
import '../../core/routes.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/wallet.dart';
import '../../ui/day_label.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/p_donut.dart';
import '../../ui/widgets/p_month_bars.dart';
import '../../ui/widgets/widgets.dart';
import 'finance_strings.dart';

DateTime _date(LocalDate day) => DateTime(day.year, day.month, day.day);

String _monthName(LocalMonth month) => monthLabel(_date(month.firstDay));

/// One budget month: totals, spending by category, six months, budgets and,
/// for the current month, wallet balances.
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  /// Null follows the current month.
  LocalMonth? _picked;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final period = ref.watch(budgetPeriodProvider);
    final current = period.value?.month;
    final month = _picked ?? current;
    final summary = month == null
        ? null
        : ref.watch(financeSummaryProvider(month));
    final budgets = month == null
        ? null
        : ref.watch(monthBudgetsProvider(month));
    final balances = ref.watch(walletBalancesProvider);
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? <Category>[])
        c.id: c,
    };
    final data = summary?.value;
    final failed =
        period.hasError ||
        (summary?.hasError ?? false) ||
        (budgets?.hasError ?? false) ||
        balances.hasError;

    return PScreen(
      title: FinanceStrings.summary,
      onBack: () => context.go(Routes.finance),
      child: ListView(
        padding: const EdgeInsets.only(bottom: MelaSpace.s6),
        children: [
          if (month != null)
            _MonthPicker(
              month: month,
              period: data?.period,
              today: today,
              onPrevious: () => setState(() => _picked = month.addMonths(-1)),
              onNext: month == current
                  ? null
                  : () => setState(() {
                      final next = month.addMonths(1);
                      _picked = next == current ? null : next;
                    }),
            ),
          if (failed)
            const EmptyState(
              icon: LucideIcons.circleAlert,
              title: FinanceStrings.loadError,
            ),
          if (data != null) ..._summary(data, categories),
          ..._budgets(budgets?.value ?? const [], categories),
          if (month == current) ..._wallets(balances.value ?? const []),
        ],
      ),
    );
  }

  List<Widget> _summary(MonthSummary data, Map<String, Category> categories) {
    final months = data.summary.months;
    final picked = months.last;
    final hasAny = months.any((m) => m.income.value + m.spent.value > 0);
    return [
      if (picked.income.value + picked.spent.value == 0)
        const EmptyState(
          icon: LucideIcons.chartPie,
          title: FinanceStrings.noRecords,
        )
      else ...[
        _Totals(data: data, today: ref.watch(todayProvider)),
        const PSectionHeader(FinanceStrings.byCategory),
        if (data.summary.categories.isEmpty)
          const _Note(FinanceStrings.noSpending)
        else
          _ByCategory(
            slices: data.summary.categories,
            total: picked.spent,
            categories: categories,
          ),
      ],
      if (hasAny) ...[
        const PSectionHeader(FinanceStrings.lastSixMonths),
        _SixMonths(months: months),
      ],
    ];
  }

  List<Widget> _budgets(
    List<BudgetStatus> budgets,
    Map<String, Category> categories,
  ) => [
    if (budgets.isNotEmpty) const PSectionHeader(FinanceStrings.budgets),
    for (final status in budgets)
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MelaSpace.s4,
          vertical: MelaSpace.s2,
        ),
        child: PBudgetBar(
          category: categories[status.categoryId]?.name ?? '',
          color:
              categories[status.categoryId]?.color ??
              MelaIdentity.slate.toARGB32(),
          icon: categories[status.categoryId]?.icon ?? 'tag',
          spent: status.spent,
          cap: status.cap,
        ),
      ),
  ];

  List<Widget> _wallets(List<WalletBalance> balances) {
    final live = [
      for (final w in balances)
        if (!w.wallet.isArchived) w,
    ];
    // As in WalletRepository.watchLiquidTotal.
    final total = live
        .where((w) => w.wallet.includeInTotal)
        .fold(Rupiah.zero, (sum, w) => sum + w.balance);
    return [
      if (live.isNotEmpty) ...[
        const PSectionHeader(FinanceStrings.walletsToday),
        for (final WalletBalance(:wallet, :balance) in live)
          _Line(
            leading: PIconTile(
              icon: melaIcon(wallet.icon, fallback: LucideIcons.wallet),
              color: identityColor(wallet.color),
            ),
            title: wallet.name,
            meta: wallet.includeInTotal ? null : FinanceStrings.notInTotal,
            amount: AmountText(balance, type: AmountType.balance),
          ),
        _Line(
          title: FinanceStrings.total,
          amount: AmountText(
            total,
            type: AmountType.balance,
            size: AmountSize.lg,
          ),
        ),
      ],
    ];
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.month,
    required this.period,
    required this.today,
    required this.onPrevious,
    required this.onNext,
  });

  final LocalMonth month;
  final SummaryPeriod? period;
  final LocalDate today;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    // A month that starts on another day than the 1st says its dates.
    final range = period != null && period!.from.day != 1
        ? '${dateLabel(period!.from, today)} – ${dateLabel(period!.to, today)}'
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MelaSpace.s2),
      child: Row(
        children: [
          PButton.ghost(
            icon: LucideIcons.chevronLeft,
            semanticLabel: FinanceStrings.previousMonth,
            onPressed: onPrevious,
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text(
                    monthYearLabel(_date(month.firstDay)),
                    textAlign: TextAlign.center,
                    style: MelaText.title,
                  ),
                  if (range != null)
                    Text(
                      range,
                      textAlign: TextAlign.center,
                      style: MelaText.caption.copyWith(
                        color: colors.mutedForeground,
                        fontFeatures: MelaText.amount.fontFeatures,
                      ),
                    ),
                ],
              ),
            ),
          ),
          PButton.ghost(
            icon: LucideIcons.chevronRight,
            semanticLabel: FinanceStrings.nextMonth,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.data, required this.today});

  final MonthSummary data;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final picked = data.summary.months.last;
    final muted = MelaText.caption.copyWith(
      color: colors.mutedForeground,
      fontFeatures: MelaText.amount.fontFeatures,
    );
    final net = picked.income - picked.spent;
    final change = data.summary.change;

    String? comparison() {
      if (change == null) return null;
      final month = _monthName(picked.month.addMonths(-1));
      final byNow =
          !today.isBefore(data.period.from) && !today.isAfter(data.period.to);
      final amount = formatRupiah(change);
      return switch (change.value.sign) {
        1 =>
          byNow
              ? FinanceStrings.moreThanByNow(amount, month)
              : FinanceStrings.moreThan(amount, month),
        -1 =>
          byNow
              ? FinanceStrings.lessThanByNow(amount, month)
              : FinanceStrings.lessThan(amount, month),
        _ =>
          byNow
              ? FinanceStrings.sameByNow(month)
              : FinanceStrings.sameAs(month),
      };
    }

    Widget spread(String label, Widget amount) => Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: MelaSpace.s3,
      children: [
        Text(label, style: muted),
        // A trillion shrinks, whole, instead of being cut off.
        FittedBox(fit: BoxFit.scaleDown, child: amount),
      ],
    );

    final compared = comparison();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MelaSpace.s4,
        MelaSpace.s3,
        MelaSpace.s4,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(MelaSpace.s4),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(MelaRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: MelaSpace.s2,
          children: [
            spread(
              FinanceStrings.spending,
              AmountText(picked.spent, size: AmountSize.lg),
            ),
            spread(
              FinanceStrings.income,
              AmountText(picked.income, type: AmountType.income),
            ),
            Text(
              switch (net.value.sign) {
                1 => FinanceStrings.leftOver(formatRupiah(net)),
                -1 => FinanceStrings.overIncome(formatRupiah(net)),
                _ => FinanceStrings.evenWithIncome,
              },
              style: MelaText.bodyStrong.copyWith(
                fontFeatures: MelaText.amount.fontFeatures,
              ),
            ),
            if (compared != null) Text(compared, style: muted),
          ],
        ),
      ),
    );
  }
}

class _ByCategory extends StatelessWidget {
  const _ByCategory({
    required this.slices,
    required this.total,
    required this.categories,
  });

  final List<CategorySpend> slices;
  final Rupiah total;
  final Map<String, Category> categories;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    // "Other" takes a neutral that is none of the ten identity colours.
    Color colorOf(CategorySpend slice) => slice.categoryId == null
        ? colors.input
        : identityColor(
            categories[slice.categoryId]?.color ??
                MelaIdentity.slate.toARGB32(),
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: MelaSpace.s3),
          child: PDonut(
            segments: [
              for (final s in slices)
                (value: s.amount.value, color: colorOf(s)),
            ],
            center: AmountText(total, size: AmountSize.lg),
          ),
        ),
        for (final slice in slices)
          _Line(
            leading: PIconTile(
              icon: slice.categoryId == null
                  ? LucideIcons.ellipsis
                  : melaIcon(categories[slice.categoryId]?.icon ?? 'tag'),
              color: colorOf(slice),
            ),
            title: slice.categoryId == null
                ? FinanceStrings.otherCategories
                : categories[slice.categoryId]?.name ?? '',
            meta: FinanceStrings.percent(
              slice.amount.value * 100 ~/ total.value,
            ),
            amount: AmountText(slice.amount),
          ),
      ],
    );
  }
}

class _SixMonths extends StatelessWidget {
  const _SixMonths({required this.months});

  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final caption = MelaText.caption.copyWith(
      color: colors.mutedForeground,
      fontFeatures: MelaText.amount.fontFeatures,
    );
    final top = months.fold(
      0,
      (m, e) =>
          [m, e.income.value, e.spent.value].reduce((a, b) => a > b ? a : b),
    );

    Widget key(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: MelaSpace.s1,
      children: [
        Container(
          width: MelaSpace.s3,
          height: MelaSpace.s3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(MelaSpace.s1),
          ),
        ),
        Text(label, style: caption),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MelaSpace.s4,
        vertical: MelaSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MelaSpace.s2,
        children: [
          Wrap(
            spacing: MelaSpace.s4,
            children: [
              key(colors.positive, FinanceStrings.income),
              key(colors.foreground, FinanceStrings.spending),
            ],
          ),
          Text(
            FinanceStrings.highest(formatRupiah(Rupiah(top))),
            style: caption,
          ),
          PMonthBars(
            months: [
              for (final m in months)
                (
                  label: monthShort(_date(m.month.firstDay)),
                  semanticLabel: FinanceStrings.monthBars(
                    monthYearLabel(_date(m.month.firstDay)),
                    formatRupiah(m.income),
                    formatRupiah(m.spent),
                  ),
                  income: m.income.value,
                  spent: m.spent.value,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: MelaSpace.s4,
      vertical: MelaSpace.s2,
    ),
    child: Text(
      text,
      style: MelaText.body.copyWith(
        color: ShadTheme.of(context).colorScheme.mutedForeground,
      ),
    ),
  );
}

/// A read-only row: name, an optional second line and an amount.
class _Line extends StatelessWidget {
  const _Line({
    this.leading,
    required this.title,
    this.meta,
    required this.amount,
  });

  final Widget? leading;
  final String title;
  final String? meta;
  final Widget amount;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MelaSpace.s4,
        vertical: MelaSpace.s2,
      ),
      child: Row(
        spacing: MelaSpace.s3,
        children: [
          ?leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MelaText.bodyStrong,
                ),
                if (meta != null)
                  Text(
                    meta!,
                    style: MelaText.caption.copyWith(
                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                      fontFeatures: MelaText.amount.fontFeatures,
                    ),
                  ),
              ],
            ),
          ),
          TrailingAmount(child: amount),
        ],
      ),
    ),
  );
}
