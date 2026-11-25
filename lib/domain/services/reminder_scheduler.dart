import '../entities/action_item.dart';
import '../entities/recurring_rule.dart';

/// Implemented in data/platform.
abstract interface class ReminderScheduler {
  Future<void> scheduleItem(ActionItem item); // same notifId = replace
  Future<void> scheduleRule(RecurringRule rule);
  Future<void> cancel(int notifId);
  Future<void> resyncAll(); // bootstrap, restore, timezone change
}
