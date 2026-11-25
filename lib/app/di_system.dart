// Providers owned by the reminders + backup + settings thread (G). Exported by
// di.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform/noop_reminder_scheduler.dart';
import '../domain/services/reminder_scheduler.dart';

/// A no-op until local notifications land.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => const NoopReminderScheduler(),
);
