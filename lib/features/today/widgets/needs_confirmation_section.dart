import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/local_date.dart';
import '../../../domain/entities/action_item.dart';
import '../../../domain/entities/recurring_occurrence.dart';
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

    // The wallet confirming would use: the linked one unless it is archived,
    // else the default (same rule as the bill draft).
    String? walletName(String? id) {
      String? fallback;
      for (final b in wallets) {
        if (b.wallet.id == id && !b.wallet.isArchived) return b.wallet.name;
        if (b.wallet.isDefault) fallback = b.wallet.name;
      }
      return fallback;
    }

    // A rule posts to its own wallet or not at all: no fallback.
    String? ruleWalletName(String id) =>
        wallets.where((b) => b.wallet.id == id).firstOrNull?.wallet.name;

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
          child: PSectionHeader(MelaStrings.needsConfirmation),
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
            final pending = occurrences[i];
            final PendingOccurrence(:occurrence, :rule) = pending;
            return PConfirmRow(
              key: ValueKey(occurrence.id),
              title: rule.name,
              source: ConfirmSource.recurring,
              amount: rule.amount,
              type: AmountType.of(rule.type),
              meta: [
                ?ruleWalletName(rule.walletId),
                dayLabel(occurrence.occurrenceDate, today),
              ].join(' · '),
              onConfirm: () =>
                  PlannerFlows.of(context).confirmOccurrence(pending),
              onEdit: () => PlannerFlows.of(context).editOccurrence(pending),
              onSkip: () => PlannerFlows.of(context).skipOccurrence(pending),
            );
          },
        ),
      ],
    );
  }
}
