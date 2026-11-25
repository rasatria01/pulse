import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/parser/capture_parser.dart';
import 'package:pulse/domain/parser/parse_result.dart';
import 'package:pulse/domain/services/default_capture_service.dart';
import 'package:pulse/domain/services/reminder_scheduler.dart';

import '../../data/support.dart';

final class _FakeScheduler implements ReminderScheduler {
  final scheduled = <ActionItem>[];
  final cancelled = <int>[];
  bool broken = false;

  @override
  Future<void> scheduleItem(ActionItem item) async {
    if (broken) throw Exception('no alarms');
    scheduled.add(item);
  }

  @override
  Future<void> scheduleRule(RecurringRule rule) async {}

  @override
  Future<void> cancel(int notifId) async => cancelled.add(notifId);

  @override
  Future<void> resyncAll() async {}
}

void main() {
  late Harness h;
  late _FakeScheduler alarms;
  late DefaultCaptureService service;

  setUp(() {
    h = Harness();
    alarms = _FakeScheduler();
    service = DefaultCaptureService(
      unitOfWork: h.unitOfWork,
      transactions: h.transactions,
      actionItems: h.items,
      notes: h.notes,
      tags: h.tags,
      search: h.search,
      settings: h.settings,
      reminders: alarms,
    );
  });
  tearDown(() => h.db.close());

  Future<ParseResult> parse(String text) async => parseCapture(
    text,
    ParseContext(
      const FixedClock().nowLocal(),
      await h.wallets.refs(),
      await h.categories.refs(),
    ),
  );

  Future<List<String>> liveTags() async => [
    for (final t in await h.tags.watchAll().first) t.slug,
  ];

  test('a transaction is saved with its day, tags and raw input', () async {
    final outcome = await service.commit(
      await parse('-25rb parkir kemarin #motor'),
    );
    final saved = (await h.transactions.find(outcome.entityId))!;
    expect(saved.type, TxnType.outcome);
    expect(saved.amount.value, 25000);
    expect(saved.occurredOn, const LocalDate(2026, 11, 24));
    expect(saved.tagIds, outcome.createdTagIds);
    final raw = await h.sql('SELECT raw_input FROM transactions');
    expect(raw.single.read<String>('raw_input'), contains('parkir'));
  });

  test('a draft with a blocking issue is refused', () async {
    final draft = await parse('-35k @nope');
    await expectLater(service.commit(draft), throwsA(isA<ValidationFailure>()));
    expect(await h.sql('SELECT 1 FROM transactions'), isEmpty);
  });

  test('a failure leaves no tag or row behind', () async {
    final draft = await parse('-35k #fresh');
    // The wallet is archived between parse and save.
    final other = await h.addWallet('bank');
    final cash = await h.cash();
    await h.wallets.setDefault(other.id);
    await h.wallets.archive(cash.id);
    await expectLater(service.commit(draft), throwsA(isA<ValidationFailure>()));
    expect(await h.sql('SELECT 1 FROM transactions'), isEmpty);
    expect(await liveTags(), isEmpty);
  });

  test('timed and due items get a notification id and an alarm', () async {
    final a = await service.commit(await parse('standup 14:00'));
    final b = await service.commit(await parse('report besok'));
    await service.commit(await parse('someday'));
    final ids = [for (final item in alarms.scheduled) item.notifId];
    expect(ids, [1, 2]);
    expect(alarms.scheduled.map((i) => i.id), [a.entityId, b.entityId]);

    await service.undo(a);
    expect(await h.items.find(a.entityId), isNull);
    expect(alarms.cancelled, [1]);
  });

  test('a broken scheduler does not fail the save', () async {
    alarms.broken = true;
    final outcome = await service.commit(await parse('standup 14:00'));
    expect(await h.items.find(outcome.entityId), isNotNull);
  });

  test('undo removes taggings and only the orphaned new tags', () async {
    await service.commit(await parse('note: first #old'));
    final second = await service.commit(await parse('-5k #old #new #shared'));
    // Another entry picks up a tag before the Undo.
    await service.commit(await parse('call mum #shared'));

    await service.undo(second);
    expect(await h.transactions.find(second.entityId), isNull);
    expect(await liveTags(), ['old', 'shared']);
    final taggings = await h.sql(
      "SELECT 1 FROM taggings WHERE is_deleted = 0 AND entity_type = "
      "'transaction'",
    );
    expect(taggings, isEmpty);
  });
}
