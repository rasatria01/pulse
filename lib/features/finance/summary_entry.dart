import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../ui/day_label.dart';
import '../../ui/widgets/common.dart' show PTapTarget;
import '../../ui/widgets/widgets.dart';
import 'finance_strings.dart';

/// The row at the top of Finance that opens the summary.
class SummaryEntry extends ConsumerWidget {
  const SummaryEntry({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ShadTheme.of(context).colorScheme;
    final month = ref.watch(budgetPeriodProvider).value?.month;
    final data = month == null
        ? null
        : ref.watch(financeSummaryProvider(month)).value;
    final title = month == null
        ? FinanceStrings.summary
        : FinanceStrings.monthSummary(monthLabel(DateTime(0, month.month)));
    final spent = data?.summary.months.last.spent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MelaSpace.s4),
      child: PTapTarget(
        label: spent == null
            ? title
            : '$title, ${amountLabel(spent, AmountType.outcome)}',
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(MelaSpace.s4),
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(MelaRadius.xl),
          ),
          child: Row(
            spacing: MelaSpace.s3,
            children: [
              const PIconTile(icon: LucideIcons.chartPie),
              // Stacked: side by side, the title breaks mid-word at 1.3x.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MelaText.bodyStrong),
                    if (spent != null) AmountText(spent),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: MelaSize.iconSm,
                color: colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
