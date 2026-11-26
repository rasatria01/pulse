import 'package:flutter/widgets.dart';

import '../../domain/entities/action_item.dart';
import '../../domain/entities/tag.dart';
import '../widgets/p_timeline_item.dart';
import 'planner_format.dart';
import 'planner_strings.dart';

/// An item with no end draws this long (PRD F2).
const _defaultLength = Duration(minutes: 30);

/// The one item on a screen that is "now": the first of today's [timed] items,
/// earliest first, that is open and not over yet.
String? nowItemId(List<ActionItem> timed, DateTime nowUtc) {
  for (final item in timed) {
    final start = item.scheduledStart;
    if (start == null || item.status == ActionStatus.done) continue;
    final end = item.scheduledEnd ?? start.add(_defaultLength);
    if (nowUtc.isBefore(end)) return item.id;
  }
  return null;
}

/// One timeline or agenda row. [due] puts it in the Due lane.
class AgendaRow extends StatelessWidget {
  const AgendaRow({
    super.key,
    required this.item,
    required this.tags,
    required this.onOpen,
    this.due = false,
    this.now = false,
  });

  final ActionItem item;
  final List<Tag> tags;
  final VoidCallback onOpen;
  final bool due;

  /// Marked turmeric. See [nowItemId].
  final bool now;

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
      now: now,
      onPressed: onOpen,
    );
  }
}
