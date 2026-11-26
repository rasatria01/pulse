import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/clock.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/services/recurring_engine_impl.dart';
import 'package:pulse/domain/services/recurring_rule_service.dart';
import 'package:pulse/domain/services/reminder_scheduler.dart';

import '../data/support.dart';

class _Alarms implements ReminderScheduler {
  /// notifId -> the next due date its alarm was set for.
  final rules = <int, LocalDate>{};

  @override
  Future<void> scheduleRule(RecurringRule rule) async {
    if (rule.isPaused) {
      rules.remove(rule.notifId);
    } else {
      rules[rule.notifId!] = rule.nextDueDate;
    }
  }

  @override
  Future<void> cancel(int notifId) async => rules.remove(notifId);

  @override
  Future<void> scheduleItem(ActionItem item) async {}

  @override
  Future<void> resyncAll() async {}
}

DefaultRecurringEngine _engine(Harness h, [ReminderScheduler? alarms]) =>
    DefaultRecurringEngine(
      rules: h.recurring,
      transactions: h.transactions,
      reminders: alarms ?? _Alarms(),
      unitOfWork: h.unitOfWork,
    );

Future<RecurringRuleInput> _input(
  Harness h, {
  required LocalDate start,
  RecurFreq freq = RecurFreq.monthly,
  LocalDate? end,
  bool autoPost = true,
  String? walletId,
}) async => RecurringRuleInput(
  name: 'Rent',
  type: TxnType.outcome,
  amount: const Rupiah(100000),
  walletId: walletId ?? (await h.cash()).id,
  freq: freq,
  startDate: start,
  nextDueDate: start,
  endDate: end,
  autoPost: autoPost,
);

Future<List<String>> _postedOn(Harness h) async => [
  for (final row in await h.sql(
    'SELECT occurred_on FROM transactions WHERE is_deleted = 0 '
    'ORDER BY occurred_on',
  ))
    row.read<String>('occurred_on'),
];

Future<int> _count(Harness h, String table) async =>
    (await h.sql('SELECT COUNT(*) AS n FROM $table')).single.read<int>('n');

void main() {
  group('engine', () {
    late Harness h;
    setUp(() => h = Harness());
    tearDown(() => h.db.close());

    test('M3: once per occurrence across runs and restarts; '
        'day 31 posts 2027-02-28', () async {
      final dir = Directory.systemTemp.createTempSync('pulse-m3');
      addTearDown(() => dir.deleteSync(recursive: true));
      Harness open() => Harness(NativeDatabase(File('${dir.path}/db.sqlite')));

      var disk = open();
      await disk.recurring.create(
        await _input(disk, start: const LocalDate(2026, 12, 31)),
      );
      const day = LocalDate(2027, 3, 1);
      // Overlapping runs, as start, resume and midnight can.
      final reports = await Future.wait([
        _engine(disk).catchUp(day),
        _engine(disk).catchUp(day),
      ]);
      expect(reports.fold(0, (n, r) => n + r.posted), 3);
      expect((await _engine(disk).catchUp(day)).posted, 0);
      await disk.db.close();

      disk = open();
      expect((await _engine(disk).catchUp(day)).posted, 0);
      expect(await _postedOn(disk), ['2026-12-31', '2027-01-31', '2027-02-28']);
      final rule = (await disk.recurring.watchRules().first).single;
      expect(rule.nextDueDate, const LocalDate(2027, 3, 31));
      await disk.db.close();
    });

    test('an occurrence that already exists is not posted again', () async {
      final rule = await h.recurring.create(await _input(h, start: today));
      await h.recurring.insertOccurrence(rule.id, today);
      final report = await _engine(h).catchUp(today);
      expect((report.posted, report.pending), (0, 0));
      expect(await _postedOn(h), isEmpty);
      // The rule still moves on.
      expect(
        (await h.recurring.find(rule.id))!.nextDueDate,
        const LocalDate(2026, 12, 25),
      );
    });

    test('366 per run, then the rest', () async {
      await h.recurring.create(
        await _input(
          h,
          start: today.addDays(-399),
          freq: RecurFreq.daily,
          autoPost: false,
        ),
      );
      expect((await _engine(h).catchUp(today)).pending, 366);
      expect((await _engine(h).catchUp(today)).pending, 34);
      expect(await _count(h, 'transactions'), 0);
    });

    test('end date and pause stop a rule', () async {
      await h.recurring.create(
        await _input(
          h,
          start: today.addDays(-5),
          freq: RecurFreq.daily,
          end: today.addDays(-3),
        ),
      );
      final paused = await h.recurring.create(
        await _input(h, start: today, freq: RecurFreq.daily),
      );
      await h.recurring.update(
        paused.id,
        const RecurringRulePatch(isPaused: true),
      );
      expect((await _engine(h).catchUp(today)).posted, 3);
      expect((await _engine(h).catchUp(today)).posted, 0);
    });

    test('a rule that cannot post stays pending in its own wallet', () async {
      final bank = await h.addWallet('bank');
      await h.recurring.create(
        await _input(h, start: today, walletId: bank.id),
      );
      await h.wallets.archive(bank.id);
      final report = await _engine(h).catchUp(today);
      expect((report.posted, report.pending), (0, 1));

      final occurrence =
          (await h.recurring.watchPending().first).single.occurrence;
      await expectLater(
        _engine(h).postPending(occurrence.id),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await _count(h, 'transactions'), 0);
    });

    test('confirm posts once with the edited amount; skip and undo', () async {
      await h.recurring.create(await _input(h, start: today, autoPost: false));
      final engine = _engine(h);
      await engine.catchUp(today);
      final id = (await h.recurring.watchPending().first).single.occurrence.id;

      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          engine
              .postPending(id, amount: const Rupiah(120000))
              .then<Object>((txn) => txn, onError: (Object e) => e),
      ]);
      expect(results.whereType<ConflictFailure>(), hasLength(1));
      final txn = (await h.transactions.watchDay(today).first).single;
      expect(txn.amount, const Rupiah(120000));
      expect(txn.occurredAt, DateTime(2026, 11, 25, 12).toUtc());
      await expectLater(
        engine.skipPending(id),
        throwsA(isA<ConflictFailure>()),
      );

      await engine.reopenOccurrence(id, transactionId: txn.id);
      expect(await _postedOn(h), isEmpty);
      await engine.skipPending(id);
      expect(await h.recurring.watchPending().first, isEmpty);
      await expectLater(
        engine.postPending(id),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('rule service', () {
    late Harness h;
    late _Alarms alarms;
    late RecurringRuleService rules;

    setUp(() {
      h = Harness();
      alarms = _Alarms();
      rules = RecurringRuleService(
        rules: h.recurring,
        engine: _engine(h, alarms),
        settings: h.settings,
        reminders: alarms,
        unitOfWork: h.unitOfWork,
        clock: const FixedClock() as Clock,
      );
    });
    tearDown(() => h.db.close());

    Future<RecurringRule> only() async =>
        (await h.recurring.watchRules().first).single;

    test('create catches up and sets the alarm; pause and delete cancel it, '
        'resume skips the gap', () async {
      await rules.create(
        await _input(h, start: today.addDays(-2), freq: RecurFreq.daily),
      );
      var rule = await only();
      expect(await _postedOn(h), hasLength(3));
      expect(alarms.rules, {rule.notifId: today.addDays(1)});

      await rules.setPaused(rule.id, true);
      expect(alarms.rules, isEmpty);

      // Paused since long ago: nothing in between is posted.
      await h.recurring.setNextDue(rule.id, today.addDays(-30));
      await rules.setPaused(rule.id, false);
      expect((await only()).nextDueDate, today.addDays(1));
      expect(await _postedOn(h), hasLength(3));
      expect(alarms.rules, hasLength(1));

      await rules.delete(rule.id);
      expect(alarms.rules, isEmpty);
      expect(await h.recurring.watchRules().first, isEmpty);
    });

    test('a changed schedule never posts into the past', () async {
      await rules.create(await _input(h, start: today.addDays(10)));
      final rule = await only();
      expect(rule.nextDueDate, today.addDays(10));

      await rules.edit(
        rule.id,
        await _input(h, start: const LocalDate(2026, 1, 31)),
      );
      expect((await only()).nextDueDate, const LocalDate(2026, 11, 30));
      expect(await _postedOn(h), isEmpty);

      // The same schedule keeps its place.
      await rules.edit(
        rule.id,
        await _input(h, start: const LocalDate(2026, 1, 31), autoPost: false),
      );
      expect((await only()).nextDueDate, const LocalDate(2026, 11, 30));
    });

    test('an end before the start is refused', () async {
      await expectLater(
        rules.create(await _input(h, start: today, end: today.addDays(-1))),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
