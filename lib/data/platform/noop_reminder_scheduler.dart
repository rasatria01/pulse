import '../../domain/entities/action_item.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/services/reminder_scheduler.dart';

/// Schedules nothing, until local notifications land.
final class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> scheduleItem(ActionItem item) async {}

  @override
  Future<void> scheduleRule(RecurringRule rule) async {}

  @override
  Future<void> cancel(int notifId) async {}

  @override
  Future<void> resyncAll() async {}
}
