import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/domain/entities/recurring_occurrence.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/search.dart';
import 'package:pulse/domain/entities/tag.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/repositories/settings_repository.dart';

import 'support.dart';

const _november = LocalMonth(2026, 11);

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.db.close());

  Future<ActionItem> item(
    String title, {
    LocalDate? due,
    Priority priority = Priority.none,
    DateTime? start,
  }) => h.items.create(
    ActionItemInput(
      title: title,
      dueDate: due,
      priority: priority,
      scheduledStart: start,
    ),
  );

  Future<void> tag(EntityType type, String id, String slug) async {
    final tags = await h.tags.ensure([slug]);
    await h.tags.setTags(type, id, [for (final t in tags) t.id]);
  }

  group('action items', () {
    test('inbox: overdue, then high, then due today', () async {
      await item('due today', due: today);
      await item('high', priority: Priority.high);
      await item('overdue', due: today.addDays(-1));
      await item('older', due: today.addDays(-3));
      await item('high today', due: today, priority: Priority.high);
      // None of these belong: medium without a date, future, scheduled, done,
      // deleted.
      await item('medium', priority: Priority.med);
      await item('future', due: today.addDays(1));
      await item('scheduled', due: today, start: DateTime.utc(2026, 11, 25));
      final done = await item('done', due: today);
      await h.items.update(
        done.id,
        const ActionItemPatch(status: ActionStatus.done),
      );
      await h.items.softDelete((await item('deleted', due: today)).id);

      final inbox = await h.items.watchInbox(today).first;
      expect(
        [for (final i in inbox) i.title],
        ['older', 'overdue', 'high today', 'high', 'due today'],
      );
    });

    test('patch clears columns, tags populate, filters work', () async {
      final a = await item('a', due: today);
      await tag(EntityType.actionItem, a.id, 'work');
      final tagId = (await h.items.find(a.id))!.tagIds.single;

      final tagged = await h.items.watchTasks(TaskFilter(tagId: tagId)).first;
      expect(tagged.single.id, a.id);

      final start = DateTime.utc(2026, 11, 25, 5);
      final moved = await h.items.update(
        a.id,
        ActionItemPatch(dueDate: (value: null), scheduledStart: (value: start)),
      );
      expect((moved.dueDate, moved.scheduledStart), (null, start));
      expect(await h.items.watchTasks(const TaskFilter()).first, isEmpty);
      final hour = start.add(const Duration(hours: 1));
      final day = await h.items.watchScheduled(start, hour).first;
      expect(day.single.tagIds, [tagId]);
      // The upper bound is exclusive.
      final before = h.items.watchScheduled(DateTime.utc(2026), start);
      expect(await before.first, isEmpty);
      expect(await h.items.withFutureReminders(DateTime.utc(2026)), [moved]);
      expect(await h.items.withFutureReminders(start), isEmpty);
    });

    test('deleted items are hidden unless asked for by note', () async {
      final note = await h.notes.create(const NoteInput(title: 'n'));
      final a = await h.items.create(
        ActionItemInput(
          title: 'line',
          sourceNoteId: note.id,
          sourceBlockId: 'tabc123',
        ),
      );
      await h.items.softDelete(a.id);
      expect(await h.items.find(a.id), isNull);
      expect(await h.items.findBySourceNote(note.id), isEmpty);
      final all = await h.items.findBySourceNote(note.id, includeDeleted: true);
      expect(all.single.isDeleted, isTrue);
      await expectLater(
        h.items.create(const ActionItemInput(title: '  ')),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('notes', () {
    test('the daily note is created once; its title follows line 1', () async {
      expect(await h.notes.watchDaily(today).first, isNull);
      final daily = await h.notes.ensureDaily(today);
      expect((await h.notes.ensureDaily(today)).id, daily.id);

      await h.notes.saveBody(daily.id, '# Plan\n- [ ] milk ^tabc123');
      final saved = await h.notes.saveBody(
        daily.id,
        '# Plans\n- [ ] milk ^tabc123',
      );
      expect(saved.title, 'Plans');
      expect((await h.notes.watchAll().first).single.preview, 'milk');

      await h.notes.update(daily.id, const NotePatch(title: 'Mine'));
      expect((await h.notes.saveBody(daily.id, 'other')).title, 'Mine');

      await tag(EntityType.note, daily.id, 'diary');
      expect((await h.notes.watch(daily.id).first)!.tagIds, hasLength(1));
      await h.notes.softDelete(daily.id);
      expect(await h.notes.watch(daily.id).first, isNull);
      expect(await h.notes.watchAll().first, isEmpty);
    });
  });

  group('budgets', () {
    test('the latest cap at or before the month is in force', () async {
      final food = await h.category('food', CategoryKind.outcome);
      final bills = await h.category('bills', CategoryKind.outcome);
      final cash = await h.cash();
      await h.budgets.setCap(
        food.id,
        const Rupiah(100),
        const LocalMonth(2026, 9),
      );
      await h.budgets.setCap(food.id, const Rupiah(300), _november);
      await h.budgets.setCap(food.id, const Rupiah(400), _november);
      await h.budgets.setCap(
        bills.id,
        const Rupiah(50),
        const LocalMonth(2026, 12),
      );
      await h.transactions.create(
        txn(TxnType.outcome, 80, cash.id, category: food.id),
      );
      await h.transactions.create(
        txn(
          TxnType.outcome,
          7,
          cash.id,
          category: food.id,
          on: const LocalDate(2026, 11, 2),
        ),
      );

      expect(
        await h.budgets.totalCaps(const LocalMonth(2026, 10)),
        const Rupiah(100),
      );
      expect(await h.budgets.totalCaps(_november), const Rupiah(400));
      final status = (await h.budgets.watchMonth(_november).first).single;
      expect((status.cap.value, status.spent.value), (400, 87));

      // A period starting on the 10th leaves the 2nd out.
      await h.settings.put(SettingKeys.budgetMonthStartDay, '10');
      expect(
        (await h.budgets.watchMonth(_november).first).single.spent,
        const Rupiah(80),
      );

      await h.budgets.setCap(food.id, Rupiah.zero, _november);
      expect(await h.budgets.watchMonth(_november).first, isEmpty);
      final income = await h.category('income', CategoryKind.income);
      await expectLater(
        h.budgets.setCap(income.id, const Rupiah(1), _november),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('recurring', () {
    Future<RecurringRule> rule({LocalDate? end}) async => h.recurring.create(
      RecurringRuleInput(
        name: 'rent',
        type: TxnType.outcome,
        amount: const Rupiah(1000),
        walletId: (await h.cash()).id,
        freq: RecurFreq.monthly,
        startDate: today,
        endDate: end,
        nextDueDate: today,
      ),
    );

    test('one occurrence per date, resolved only once', () async {
      final r = await rule();
      expect(r.categoryId, isNotNull);
      final id = await h.recurring.insertOccurrence(r.id, today);
      await expectLater(
        h.recurring.insertOccurrence(r.id, today),
        throwsA(isA<ConflictFailure>()),
      );
      final pending = (await h.recurring.watchPending().first).single;
      expect((pending.rule.id, pending.occurrence.id), (r.id, id));

      // Posted needs a transaction.
      await expectLater(
        h.recurring.resolveOccurrence(id, OccurrenceStatus.posted),
        throwsA(isA<ValidationFailure>()),
      );
      final posted = await h.transactions.create(
        txn(TxnType.outcome, 1000, r.walletId),
      );
      await h.recurring.resolveOccurrence(
        id,
        OccurrenceStatus.posted,
        transactionId: posted.id,
      );
      await expectLater(
        h.recurring.resolveOccurrence(id, OccurrenceStatus.skipped),
        throwsA(isA<ConflictFailure>()),
      );
      expect(await h.recurring.watchPending().first, isEmpty);
    });

    test('due rules skip paused, ended and deleted ones', () async {
      final r = await rule(end: today);
      expect(await h.recurring.dueOnOrBefore(today), [r]);
      expect(await h.recurring.dueOnOrBefore(today.addDays(-1)), isEmpty);

      await h.recurring.setNextDue(r.id, today.addDays(30));
      expect(await h.recurring.dueOnOrBefore(today.addDays(60)), isEmpty);

      final other = await rule();
      await h.recurring.update(
        other.id,
        const RecurringRulePatch(isPaused: true),
      );
      expect(await h.recurring.dueOnOrBefore(today), isEmpty);

      await h.recurring.insertOccurrence(other.id, today);
      await h.recurring.softDelete(other.id);
      expect(await h.recurring.find(other.id), isNull);
      expect(await h.recurring.watchPending().first, isEmpty);
      expect((await h.recurring.watchRules().first).single.id, r.id);
    });
  });

  group('search', () {
    Future<List<String>> titles(
      String text, {
      EntityType? type,
      List<String> tags = const [],
    }) async => [
      for (final hit in await h.search.search(
        SearchQuery(text: text, type: type, tagSlugs: tags),
      ))
        hit.title,
    ];

    setUp(() async {
      final cash = await h.cash();
      final t = await h.transactions.create(
        txn(TxnType.outcome, 5, cash.id, description: 'coffee beans'),
      );
      final a = await item('coffee with Ana');
      await h.notes.create(const NoteInput(title: 'Café list', body: 'coffee'));
      await h.notes.create(const NoteInput(title: 'Coffee', body: 'roasting'));
      await tag(EntityType.transaction, t.id, 'work');
      await tag(EntityType.actionItem, a.id, 'workshop');
    });

    test('prefix match, grouped by type, title ranked above body', () async {
      expect(await titles('cof'), [
        'coffee beans',
        'coffee with Ana',
        'Coffee',
        'Café list',
      ]);
      expect(await titles('cafe'), ['Café list']);
      expect(await titles('cof', type: EntityType.note), [
        'Coffee',
        'Café list',
      ]);
      expect(await titles('coffee ana'), ['coffee with Ana']);
    });

    test('tags are exact filters, with or without words', () async {
      expect(await titles('#work'), ['coffee beans']);
      expect(await titles('coffee #Workshop'), ['coffee with Ana']);
      expect(await titles('', tags: ['work']), ['coffee beans']);
      expect(await titles('#wor'), isEmpty);
      expect(await titles('#work #workshop'), isEmpty);
    });

    test('FTS syntax in the input is inert', () async {
      for (final input in [
        '"',
        "'",
        '*',
        '(',
        ')',
        'a:',
        '^',
        '-',
        '+',
        '{x}',
        'NEAR(',
        '""*',
        '# ',
        '\u0000',
        "'; DROP TABLE notes; --",
        '   ',
      ]) {
        await expectLater(titles(input), completes, reason: input);
      }
      expect(await titles('AND'), isEmpty);
      expect(await titles('title:coffee'), isEmpty);
      expect(await titles('"coffee" ('), hasLength(4));
    });

    test('soft-deleted rows never return, also after a rebuild', () async {
      final note = (await h.notes.watchAll().first).firstWhere(
        (n) => n.title == 'Coffee',
      );
      await h.notes.softDelete(note.id);
      expect(await titles('roasting'), isEmpty);
      await h.search.rebuildIndex();
      expect(await titles('roasting'), isEmpty);
      expect(await titles('cof'), hasLength(3));
    });
  });
}
