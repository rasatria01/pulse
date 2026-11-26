// When a reminder fires, and whether one is wanted at all (PRD F4, 9.3). Pure.
import '../../core/local_date.dart';
import '../../domain/entities/action_item.dart';
import '../../domain/entities/recurring_occurrence.dart';
import '../../domain/entities/recurring_rule.dart';

typedef TimeOfDayHm = ({int hour, int minute});

/// The due_reminder_time setting ('HH:mm'); 08:00 when unset or unreadable.
TimeOfDayHm parseDueTime(String? raw) {
  final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(raw ?? '');
  if (m == null) return (hour: 8, minute: 0);
  return (hour: int.parse(m[1]!), minute: int.parse(m[2]!));
}

/// The UTC instant to notify at, or null for no reminder. A timed item uses its
/// start minus the offset; a due date alone uses [dueTime] local on that day.
DateTime? itemReminderAt(
  ActionItem item, {
  required DateTime nowUtc,
  required TimeOfDayHm dueTime,
}) {
  if (item.isDeleted || item.status != ActionStatus.open) return null;
  final start = item.scheduledStart;
  if (start != null) {
    final offset = Duration(minutes: item.reminderOffsetMin ?? 0);
    return _ifFuture(start.toUtc().subtract(offset), nowUtc);
  }
  final due = item.dueDate;
  if (due == null) return null;
  return _ifFuture(_localAt(due, dueTime), nowUtc);
}

/// A rule notifies at [dueTime] on its next due date, until it is paused or
/// past its end date.
DateTime? ruleReminderAt(
  RecurringRule rule, {
  required DateTime nowUtc,
  required TimeOfDayHm dueTime,
}) {
  final end = rule.endDate;
  if (rule.isPaused || (end != null && rule.nextDueDate.isAfter(end))) {
    return null;
  }
  return _ifFuture(_localAt(rule.nextDueDate, dueTime), nowUtc);
}

/// A pending occurrence still rings at [dueTime] on its own day: catch-up moves
/// the rule on to the next date as soon as the app is opened. Posted (by hand or
/// auto-post) and skipped ones leave nothing to do, so they stay silent.
DateTime? occurrenceReminderAt(
  PendingOccurrence found, {
  required DateTime nowUtc,
  required TimeOfDayHm dueTime,
}) {
  final occurrence = found.occurrence;
  if (found.rule.isPaused || occurrence.status != OccurrenceStatus.pending) {
    return null;
  }
  return _ifFuture(_localAt(occurrence.occurrenceDate, dueTime), nowUtc);
}

/// Wall time on [day] in the device timezone, as a UTC instant.
DateTime _localAt(LocalDate day, TimeOfDayHm time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute).toUtc();

DateTime? _ifFuture(DateTime at, DateTime nowUtc) =>
    at.isAfter(nowUtc) ? at : null;
