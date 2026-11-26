import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../../app/di.dart';
import '../../../ui/planner/agenda_row.dart';
import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Today's schedule and Due lane. Returns a sliver.
class TimelineSection extends ConsumerWidget {
  const TimelineSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final due = ref.watch(dueLaneProvider(today)).value;
    final timed = ref.watch(timelineProvider(today)).value;
    final tags = ref.watch(plannerTagsProvider).value ?? const [];
    final now = ref.watch(nowMinuteProvider);
    final count = (due?.length ?? 0) + (timed?.length ?? 0);

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: PSectionHeader(MelaStrings.timeline)),
        if (due != null && timed != null && count == 0)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: LucideIcons.clock,
              title: MelaStrings.noTimeline,
            ),
          ),
        // Timed first, earliest first; then the Due lane (PRD F2).
        SliverList.builder(
          itemCount: count,
          itemBuilder: (context, i) {
            final timedCount = timed?.length ?? 0;
            final inDue = i >= timedCount;
            final item = inDue ? due![i - timedCount] : timed![i];
            return AgendaRow(
              key: ValueKey((item.id, inDue)),
              item: item,
              tags: tags,
              nowUtc: now,
              due: inDue,
              onOpen: () => PlannerFlows.of(context).open(item),
            );
          },
        ),
      ],
    );
  }
}
