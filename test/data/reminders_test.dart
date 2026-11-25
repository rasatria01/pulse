import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/data/platform/alarm_platform.dart';
import 'package:pulse/data/platform/local_notifications_scheduler.dart';
import 'package:pulse/data/platform/reminder_plan.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/repositories/settings_repository.dart';

import 'support.dart';

class _FakePlatform implements AlarmPlatform {
  final alarms = <int, ({DateTime at, String title, String body})>{};

  @override
  Future<void> schedule({
    required int id,
    required DateTime atUtc,
    required String title,
    required String body,
  }) async => alarms[id] = (at: atUtc, title: title, body: body);

  @override
  Future<void> cancel(int id) async => alarms.remove(id);

  @override
  Future<List<int>> pendingIds() async => alarms.keys.toList();
}

// FixedClock: now is 2026-11-25 03:00 UTC.
final _now = DateTime.utc(2026, 11, 25, 3);
const _eight = (hour: 8, minute: 0);

ActionItem _item({
  DateTime? start,
  LocalDate? due,
  int? offset,
  ActionStatus status = ActionStatus.open,
  bool deleted = false,
}) => ActionItem(
  id: 'a',
  title: 't',
  scheduledStart: start,
  dueDate: due,
  reminderOffsetMin: offset,
  status: status,
  isDeleted: deleted,
  createdAt: _now,
  updatedAt: _now,
);

DateTime? _at(ActionItem item) =>
    itemReminderAt(item, nowUtc: _now, dueTime: _eight);

void main() {
  group('when to remind', () {
    final start = DateTime.utc(2026, 11, 26, 9);

    test('a timed item uses start minus offset, not the due date', () {
      expect(_at(_item(start: start)), start);
      expect(
        _at(_item(start: start, offset: 15, due: const LocalDate(2026, 12, 1))),
        DateTime.utc(2026, 11, 26, 8, 45),
      );
    });

    test('a due date alone uses the reminder time, local', () {
      expect(
        _at(_item(due: const LocalDate(2026, 11, 27))),
        DateTime(2026, 11, 27, 8).toUtc(),
      );
    });

    test('nothing for past, done, cancelled, deleted or undated items', () {
      expect(_at(_item(start: _now)), isNull);
      expect(
        _at(_item(start: _now.add(const Duration(hours: 1)), offset: 90)),
        isNull,
      );
      expect(_at(_item(due: const LocalDate(2026, 11, 24))), isNull);
      expect(_at(_item(start: start, status: ActionStatus.done)), isNull);
      expect(_at(_item(start: start, status: ActionStatus.cancelled)), isNull);
      expect(_at(_item(start: start, deleted: true)), isNull);
      expect(_at(_item()), isNull);
    });

    test('a rule stops when paused or past its end', () {
      final rule = RecurringRule(
        id: 'r',
        name: 'Rent',
        type: TxnType.outcome,
        amount: const Rupiah(1),
        walletId: 'w',
        freq: RecurFreq.monthly,
        startDate: const LocalDate(2026, 12, 1),
        nextDueDate: const LocalDate(2026, 12, 1),
        createdAt: _now,
        updatedAt: _now,
      );
      DateTime? at(RecurringRule r) =>
          ruleReminderAt(r, nowUtc: _now, dueTime: _eight);
      expect(at(rule), DateTime(2026, 12, 1, 8).toUtc());
      expect(at(rule.copyWith(isPaused: true)), isNull);
      expect(at(rule.copyWith(endDate: const LocalDate(2026, 11, 30))), isNull);
    });

    test('the setting falls back to 08:00', () {
      expect(parseDueTime('21:30'), (hour: 21, minute: 30));
      for (final bad in [null, '', '24:00', '8:00', 'soon']) {
        expect(parseDueTime(bad), _eight);
      }
    });
  });

  group('scheduler', () {
    late Harness h;
    late _FakePlatform platform;
    late LocalNotificationsScheduler scheduler;

    setUp(() {
      h = Harness();
      platform = _FakePlatform();
      scheduler = LocalNotificationsScheduler(
        platform: platform,
        items: h.items,
        rules: h.recurring,
        settings: h.settings,
        unitOfWork: h.unitOfWork,
        clock: const FixedClock(),
        copy: (
          startsAt: (time) => 'at $time',
          dueToday: 'due',
          recurringDue: 'recurring',
        ),
      );
    });
    tearDown(() => h.db.close());

    final tomorrow = DateTime.utc(2026, 11, 26, 9);

    test('assigns an id once and replaces the alarm with it', () async {
      final item = await h.items.create(
        ActionItemInput(title: 'Call', scheduledStart: tomorrow),
      );
      // Twice with the same stale entity, as concurrent callers would.
      await Future.wait([
        scheduler.scheduleItem(item),
        scheduler.scheduleItem(item),
      ]);
      final id = (await h.items.find(item.id))!.notifId!;
      expect(platform.alarms.keys, [id]);
      expect(platform.alarms[id]!.at, tomorrow);

      await scheduler.scheduleItem(
        (await h.items.find(item.id))!.copyWith(status: ActionStatus.done),
      );
      expect(platform.alarms, isEmpty);
    });

    test('resync matches the alarms to the database', () async {
      await h.settings.put(SettingKeys.dueReminderTime, '19:00');
      final kept = await h.items.create(
        const ActionItemInput(title: 'Due', dueDate: today),
      );
      await h.items.create(
        ActionItemInput(
          title: 'Past',
          scheduledStart: _now.subtract(const Duration(hours: 1)),
        ),
      );
      final gone = await h.items.create(
        ActionItemInput(title: 'Gone', scheduledStart: tomorrow),
      );
      await scheduler.scheduleItem(gone);
      await h.items.softDelete(gone.id); // nobody told the scheduler
      final rule = await h.recurring.create(
        RecurringRuleInput(
          name: 'Rent',
          type: TxnType.outcome,
          amount: const Rupiah(1000),
          walletId: (await h.cash()).id,
          freq: RecurFreq.monthly,
          startDate: const LocalDate(2026, 12, 1),
          nextDueDate: const LocalDate(2026, 12, 1),
        ),
      );

      await scheduler.resyncAll();

      final itemId = (await h.items.find(kept.id))!.notifId!;
      final ruleId = (await h.recurring.find(rule.id))!.notifId!;
      expect(platform.alarms.keys, unorderedEquals([itemId, ruleId]));
      expect(platform.alarms[itemId]!.at, DateTime(2026, 11, 25, 19).toUtc());
      expect(platform.alarms[ruleId]!.title, 'Rent');
    });

    test('works inside a caller transaction while a resync runs', () async {
      final item = await h.items.create(
        ActionItemInput(title: 'Bill', scheduledStart: tomorrow),
      );
      await h.unitOfWork.run(() => scheduler.scheduleItem(item));
      final id = (await h.items.find(item.id))!.notifId!;
      expect(platform.alarms.keys, [id]);

      // BillService cancels inside its transaction (PRD 9.1).
      final resync = scheduler.resyncAll();
      await h.unitOfWork.run(() async {
        await h.items.update(
          item.id,
          const ActionItemPatch(status: ActionStatus.done),
        );
        await scheduler.cancel(id);
      });
      await resync;
      expect(platform.alarms, isEmpty);
    });
  });
}
