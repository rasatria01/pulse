import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../../app/di.dart';
import '../../../domain/entities/action_item.dart';
import '../../../ui/planner/planner_format.dart';
import '../../../ui/planner/planner_strings.dart';
import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Priority inbox. Returns a sliver.
class InboxSection extends ConsumerWidget {
  const InboxSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final items = ref.watch(inboxProvider(today)).value;
    final tags = ref.watch(plannerTagsProvider).value ?? const [];

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: PSectionHeader(PulseStrings.priorityInbox),
        ),
        if (items != null && items.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: LucideIcons.inbox,
              title: PulseStrings.noInbox,
            ),
          ),
        SliverList.builder(
          itemCount: items?.length ?? 0,
          itemBuilder: (context, i) {
            final item = items![i];
            final due = item.dueDate;
            final reason = due != null && due.isBefore(today)
                ? InboxReason.overdue
                : item.priority == Priority.high
                ? InboxReason.high
                : InboxReason.today;
            return PInboxItem(
              key: ValueKey(item.id),
              title: item.title,
              reason: reason,
              dueLabel: reason == InboxReason.overdue
                  ? PlannerStrings.overdueBy(due!.daysUntil(today))
                  : null,
              meta: tagLine(item, tags),
              amount: item.linkedAmount,
              onComplete: (_) => PlannerFlows.of(context).complete(item),
              onSchedule: () => PlannerFlows.of(context).schedule(item),
              onPressed: () => PlannerFlows.of(context).open(item),
            );
          },
        ),
      ],
    );
  }
}
