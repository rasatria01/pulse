import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/local_date.dart';
import '../../../domain/entities/action_item.dart';
import '../../../ui/planner/planner_format.dart';
import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Pending occurrences and unrecorded bills. Returns a sliver; PRD F2 hides the
/// section when it is empty.
class NeedsConfirmationSection extends ConsumerWidget {
  const NeedsConfirmationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:bills, :occurrences) = ref.watch(needsConfirmationProvider);
    if (bills.isEmpty && occurrences.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final today = ref.watch(todayProvider);
    final wallets = ref.watch(plannerWalletsProvider).value ?? const [];

    // The wallet confirming would use: the linked one, else the default.
    String? walletName(String? id) {
      for (final b in wallets) {
        if (id == null ? b.wallet.isDefault : b.wallet.id == id) {
          return b.wallet.name;
        }
      }
      return null;
    }

    String? billMeta(ActionItem item) {
      final done = item.completedAt;
      final line = [
        ?walletName(item.linkedWalletId),
        if (done != null)
          dayLabel(LocalDate.fromDateTime(done.toLocal()), today),
      ].join(' · ');
      return line.isEmpty ? null : line;
    }

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: PSectionHeader(PulseStrings.needsConfirmation),
        ),
        SliverList.builder(
          itemCount: bills.length,
          itemBuilder: (context, i) {
            final item = bills[i];
            return PConfirmRow(
              key: ValueKey(item.id),
              title: item.title,
              source: ConfirmSource.bill,
              amount: item.linkedAmount,
              meta: billMeta(item),
              onConfirm: () => PlannerFlows.of(context).confirmPending(item),
              onEdit: () => PlannerFlows.of(context).editPending(item),
              onSkip: () => PlannerFlows.of(context).skipPending(item),
            );
          },
        ),
        SliverList.builder(
          itemCount: occurrences.length,
          itemBuilder: (context, i) {
            final (:occurrence, :rule) = (
              occurrence: occurrences[i].occurrence,
              rule: occurrences[i].rule,
            );
            // Wave 3 replaces this hook (see PlannerFlows.recurringNotReady).
            void later() => PlannerFlows.of(context).recurringNotReady();
            return PConfirmRow(
              key: ValueKey(occurrence.id),
              title: rule.name,
              source: ConfirmSource.recurring,
              amount: rule.amount,
              type: AmountType.of(rule.type),
              meta: [
                ?walletName(rule.walletId),
                dayLabel(occurrence.occurrenceDate, today),
              ].join(' · '),
              onConfirm: later,
              onEdit: later,
              onSkip: later,
            );
          },
        ),
      ],
    );
  }
}
