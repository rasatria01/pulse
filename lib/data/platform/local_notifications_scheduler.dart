import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../domain/entities/action_item.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/repositories/action_item_repository.dart';
import '../../domain/repositories/recurring_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/reminder_scheduler.dart';
import '../../domain/services/unit_of_work.dart';
import 'alarm_platform.dart';
import 'reminder_plan.dart';

/// The words on a notification; app/ fills them from the strings file.
typedef ReminderCopy = ({
  String Function(String time) startsAt,
  String dueToday,
  String recurringDue,
});

/// Android allows 500 pending alarms per app; the nearest ones win.
const _maxAlarms = 400;

/// Reminders as local notifications. A failure is logged and swallowed: it must
/// not fail the save or the bill that asked for the reminder.
final class LocalNotificationsScheduler implements ReminderScheduler {
  LocalNotificationsScheduler({
    required this.platform,
    required this.items,
    required this.rules,
    required this.settings,
    required this.unitOfWork,
    required this.clock,
    required this.copy,
  });

  final AlarmPlatform platform;
  final ActionItemRepository items;
  final RecurringRepository rules;
  final SettingsRepository settings;
  final UnitOfWork unitOfWork;
  final Clock clock;
  final ReminderCopy copy;

  // A resync repeats while anything changed under it. Nothing here waits on a
  // running resync: BillService may cancel inside a database transaction, and
  // that resync is waiting for the same database.
  int _changes = 0;
  Future<void>? _resync;

  @override
  Future<void> scheduleItem(ActionItem item) {
    _changes++;
    return _safely(() async {
      final alarm = _itemAlarm(item, await _dueTime());
      if (alarm == null) {
        final id = item.notifId;
        if (id != null) await platform.cancel(id);
        return;
      }
      await _set(item.notifId ?? await _assignItemId(item.id), alarm);
    });
  }

  @override
  Future<void> scheduleRule(RecurringRule rule) {
    _changes++;
    return _safely(() async {
      final alarm = _ruleAlarm(rule, await _dueTime());
      if (alarm == null) {
        final id = rule.notifId;
        if (id != null) await platform.cancel(id);
        return;
      }
      await _set(rule.notifId ?? await _assignRuleId(rule.id), alarm);
    });
  }

  @override
  Future<void> cancel(int notifId) {
    _changes++;
    return _safely(() => platform.cancel(notifId));
  }

  @override
  Future<void> resyncAll() {
    _changes++;
    return _resync ??= _resyncLoop();
  }

  Future<void> _resyncLoop() async {
    try {
      int seen;
      do {
        seen = _changes;
        await _safely(_resyncOnce);
      } while (seen != _changes);
    } finally {
      _resync = null;
    }
  }

  /// Makes the pending alarms match the database.
  Future<void> _resyncOnce() async {
    final dueTime = await _dueTime();
    final wanted = <(_Alarm, int?, Future<int?> Function())>[
      for (final item in await items.withFutureReminders(clock.nowUtc()))
        if (_itemAlarm(item, dueTime) case final alarm?)
          (alarm, item.notifId, () => _assignItemId(item.id)),
      for (final rule in await rules.watchRules().first)
        if (_ruleAlarm(rule, dueTime) case final alarm?)
          (alarm, rule.notifId, () => _assignRuleId(rule.id)),
    ]..sort((a, b) => a.$1.at.compareTo(b.$1.at));

    final kept = <int>{};
    for (final (alarm, notifId, assign) in wanted.take(_maxAlarms)) {
      await _safely(() async {
        final id = notifId ?? await assign();
        if (id == null) return;
        kept.add(id);
        await _set(id, alarm);
      });
    }
    // Last, so a failure above never leaves the phone with no alarms.
    for (final id in await platform.pendingIds()) {
      if (!kept.contains(id)) await platform.cancel(id);
    }
  }

  _Alarm? _itemAlarm(ActionItem item, TimeOfDayHm dueTime) {
    final at = itemReminderAt(item, nowUtc: clock.nowUtc(), dueTime: dueTime);
    if (at == null) return null;
    final start = item.scheduledStart?.toLocal();
    return (
      at: at,
      title: item.title,
      body: start == null
          ? copy.dueToday
          : copy.startsAt(
              '${start.hour.toString().padLeft(2, '0')}:'
              '${start.minute.toString().padLeft(2, '0')}',
            ),
    );
  }

  _Alarm? _ruleAlarm(RecurringRule rule, TimeOfDayHm dueTime) {
    final at = ruleReminderAt(rule, nowUtc: clock.nowUtc(), dueTime: dueTime);
    return at == null
        ? null
        : (at: at, title: rule.name, body: copy.recurringDue);
  }

  Future<void> _set(int? id, _Alarm alarm) async {
    // The clock moved on while the id was being assigned.
    if (id == null || !alarm.at.isAfter(clock.nowUtc())) return;
    await platform.schedule(
      id: id,
      atUtc: alarm.at,
      title: alarm.title,
      body: alarm.body,
    );
  }

  Future<TimeOfDayHm> _dueTime() async =>
      parseDueTime(await settings.watch(SettingKeys.dueReminderTime).first);

  // Read and write in one transaction, so two callers get the same id.
  Future<int?> _assignItemId(String itemId) => unitOfWork.run(() async {
    final item = await items.find(itemId);
    if (item == null) return null;
    if (item.notifId != null) return item.notifId;
    final id = await settings.nextNotificationId();
    await items.update(itemId, ActionItemPatch(notifId: id));
    return id;
  });

  Future<int?> _assignRuleId(String ruleId) => unitOfWork.run(() async {
    final rule = await rules.find(ruleId);
    if (rule == null) return null;
    if (rule.notifId != null) return rule.notifId;
    final id = await settings.nextNotificationId();
    await rules.update(ruleId, RecurringRulePatch(notifId: id));
    return id;
  });

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // The type only: messages may carry item titles.
      debugPrint('reminder failed: ${e.runtimeType}');
    }
  }
}

typedef _Alarm = ({DateTime at, String title, String body});
