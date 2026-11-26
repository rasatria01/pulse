import '../../domain/entities/action_item.dart';
import '../../domain/entities/tag.dart';
import 'planner_strings.dart';

export '../day_label.dart' show dayLabel, timeLabel, weekdayLabel;

/// "30 min", "1 h", "1 h 30 min", "1 day".
String spanLabel(int minutes) {
  if (minutes >= 1440 && minutes % 1440 == 0) {
    return PlannerStrings.days(minutes ~/ 1440);
  }
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return [
    if (h > 0) PlannerStrings.hours(h),
    if (m > 0 || h == 0) PlannerStrings.minutes(m),
  ].join(' ');
}

String? priorityLabel(Priority priority) => switch (priority) {
  Priority.none => null,
  Priority.low => PlannerStrings.low,
  Priority.med => PlannerStrings.medium,
  Priority.high => PlannerStrings.high,
};

/// "#home #admin" for the item's live tags, or null.
String? tagLine(ActionItem item, List<Tag> tags) {
  final line = [
    for (final tag in tags)
      if (item.tagIds.contains(tag.id)) '#${tag.slug}',
  ].join(' ');
  return line.isEmpty ? null : line;
}
