import 'package:flutter/widgets.dart';

import '../../domain/entities/action_item.dart';
import '../../domain/entities/tag.dart';
import '../widgets/p_timeline_item.dart';
import 'planner_format.dart';
import 'planner_strings.dart';

/// An item with no end draws this long (PRD F2).
const _defaultLength = Duration(minutes: 30);

/// One timeline or agenda row. [due] puts it in the Due lane.
class AgendaRow extends StatelessWidget {
  const AgendaRow({
    super.key,
    required this.item,
    required this.tags,
    required this.nowUtc,
    required this.onOpen,
    this.due = false,
  });

  final ActionItem item;
  final List<Tag> tags;
  final DateTime nowUtc;
  final VoidCallback onOpen;
  final bool due;

  @override
  Widget build(BuildContext context) {
    final start = due ? null : item.scheduledStart;
    final end = start == null
        ? null
        : item.scheduledEnd ?? start.add(_defaultLength);
    final offset = item.reminderOffsetMin ?? 0;
    final meta = [
      if (item.status == ActionStatus.done) PlannerStrings.done,
      ?priorityLabel(item.priority),
      if (offset > 0) PlannerStrings.before(spanLabel(offset)),
      ?tagLine(item, tags),
    ].join(' · ');
    return PTimelineItem(
      title: item.title,
      start: start == null ? null : timeLabel(start),
      end: end == null ? null : timeLabel(end),
      duration: end == null
          ? null
          : spanLabel(end.difference(start!).inMinutes),
      meta: meta.isEmpty ? null : meta,
      now: start != null && !nowUtc.isBefore(start) && nowUtc.isBefore(end!),
      onPressed: onOpen,
    );
  }
}
