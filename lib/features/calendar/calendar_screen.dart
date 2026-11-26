import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/local_date.dart';
import '../../ui/planner/agenda_row.dart';
import '../../ui/planner/planner_format.dart';
import '../../ui/planner/planner_strings.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/widgets.dart';
import 'calendar_strings.dart';

/// Day and week agenda with the Due lane (PRD F4).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  var _week = false;

  /// Null follows today across midnight.
  LocalDate? _picked;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final day = _picked ?? today;
    final weekStart = ref.watch(plannerWeekStartProvider).value ?? 1;
    final first = _week ? day.addDays(-((day.weekday - weekStart) % 7)) : day;
    final days = [for (var i = 0; i < (_week ? 7 : 1); i++) first.addDays(i)];
    final step = _week ? 7 : 1;
    String long(LocalDate d) =>
        '${DateFormat('EEE').format(DateTime(d.year, d.month, d.day))} '
        '${dayLabel(d, today)}';

    return PScreen(
      title: MelaStrings.calendar,
      actions: [
        PButton.ghost(
          icon: LucideIcons.plus,
          semanticLabel: PlannerStrings.addTask,
          onPressed: () => PlannerFlows.of(context).create(scheduleOn: day),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MelaSpace.s4),
            child: PChipRow(
              children: [
                for (final (week, label) in [
                  (false, CalendarStrings.day),
                  (true, CalendarStrings.week),
                ])
                  PChip(
                    field: CalendarStrings.view,
                    label: label,
                    selected: _week == week,
                    onPressed: () => setState(() => _week = week),
                  ),
                PChip(
                  label: CalendarStrings.goToday,
                  onPressed: () => setState(() => _picked = null),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MelaSpace.s2),
            child: Row(
              children: [
                PButton.ghost(
                  icon: LucideIcons.chevronLeft,
                  semanticLabel: CalendarStrings.previous,
                  onPressed: () => setState(() => _picked = day.addDays(-step)),
                ),
                Expanded(
                  child: Text(
                    _week
                        ? CalendarStrings.range(
                            dayLabel(days.first, today),
                            dayLabel(days.last, today),
                          )
                        : long(day),
                    textAlign: TextAlign.center,
                    style: MelaText.bodyStrong,
                  ),
                ),
                PButton.ghost(
                  icon: LucideIcons.chevronRight,
                  semanticLabel: CalendarStrings.next,
                  onPressed: () => setState(() => _picked = day.addDays(step)),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                for (final d in days)
                  _DayAgenda(
                    key: ValueKey(d),
                    day: d,
                    heading: _week ? long(d) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One day: the Due lane, then timed items. A sliver.
class _DayAgenda extends ConsumerWidget {
  const _DayAgenda({super.key, required this.day, this.heading});

  final LocalDate day;

  /// Set in the week view.
  final String? heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueLaneProvider(day)).value;
    final timed = ref.watch(timelineProvider(day)).value;
    final tags = ref.watch(plannerTagsProvider).value ?? const [];
    final now = ref.watch(nowMinuteProvider);
    final count = (due?.length ?? 0) + (timed?.length ?? 0);
    final nowId = day == ref.watch(todayProvider)
        ? nowItemId(timed ?? const [], now)
        : null;
    final loaded = due != null && timed != null;
    final colors = ShadTheme.of(context).colorScheme;

    return SliverMainAxisGroup(
      slivers: [
        if (heading != null)
          SliverToBoxAdapter(child: PSectionHeader(heading!)),
        if (loaded && count == 0)
          SliverToBoxAdapter(
            child: heading == null
                ? const EmptyState(
                    icon: LucideIcons.calendar,
                    title: MelaStrings.noEvents,
                    body: CalendarStrings.emptyBody,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MelaSpace.s4,
                      vertical: MelaSpace.s2,
                    ),
                    child: Text(
                      CalendarStrings.nothing,
                      style: MelaText.caption.copyWith(color: colors.inkSubtle),
                    ),
                  ),
          ),
        SliverList.builder(
          itemCount: count,
          itemBuilder: (context, i) {
            final inDue = i < (due?.length ?? 0);
            final item = inDue ? due![i] : timed![i - (due?.length ?? 0)];
            return AgendaRow(
              key: ValueKey((item.id, inDue)),
              item: item,
              tags: tags,
              now: !inDue && item.id == nowId,
              due: inDue,
              onOpen: () => PlannerFlows.of(context).open(item),
            );
          },
        ),
      ],
    );
  }
}
