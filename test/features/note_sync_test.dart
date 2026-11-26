// Every row of the PRD 9.2 event table, on an in-memory database.
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/domain/repositories/note_repository.dart';
import 'package:pulse/domain/services/bill_service_impl.dart';
import 'package:pulse/domain/services/checklist.dart';
import 'package:pulse/domain/services/item_service.dart';
import 'package:pulse/domain/services/note_task_sync_impl.dart';

import '../data/support.dart';
import 'planner_services_test.dart' show FakeScheduler;

/// Fails the body write that follows the item writes.
class _FailingSave implements NoteRepository {
  _FailingSave(this._notes);

  final NoteRepository _notes;

  @override
  Future<Note?> find(String id) => _notes.find(id);

  @override
  Future<Note> saveBody(String id, String body) =>
      throw const StorageFailure('disk full');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Harness h;
  late FakeScheduler reminders;
  late DefaultNoteTaskSync sync;
  late ItemService items;
  late DefaultBillService bills;
  late String noteId;

  DefaultNoteTaskSync syncOn(NoteRepository notes) => DefaultNoteTaskSync(
    notes: notes,
    items: h.items,
    tags: h.tags,
    wallets: h.wallets,
    categories: h.categories,
    transactions: h.transactions,
    settings: h.settings,
    reminders: reminders,
    unitOfWork: h.unitOfWork,
    clock: const FixedClock(),
  );

  setUp(() async {
    h = Harness();
    reminders = FakeScheduler();
    sync = syncOn(h.notes);
    items = ItemService(
      items: h.items,
      tags: h.tags,
      transactions: h.transactions,
      settings: h.settings,
      reminders: reminders,
      unitOfWork: h.unitOfWork,
      clock: const FixedClock(),
      notes: sync,
    );
    bills = DefaultBillService(
      items: h.items,
      tags: h.tags,
      wallets: h.wallets,
      categories: h.categories,
      transactions: h.transactions,
      reminders: reminders,
      unitOfWork: h.unitOfWork,
      clock: const FixedClock(),
      notes: sync,
    );
    noteId = (await h.notes.create(const NoteInput())).id;
  });
  tearDown(() => h.db.close());

  Future<String> body([String? id]) async =>
      (await h.notes.find(id ?? noteId))!.body;

  Future<List<ActionItem>> all([String? id]) =>
      h.items.findBySourceNote(id ?? noteId, includeDeleted: true);

  Future<ActionItem> only() async => (await all()).single;

  Future<String> save(String text) => sync.onNoteSaved(noteId, text);

  /// A synced "- [ ] Buy milk" and its token.
  Future<String> milk() => save('- [ ] Buy milk');

  String idOf(String line) => parseChecklist(line).single.blockId!;

  test('new line: creates the item and consumes its tokens', () async {
    final out = await save(
      'Shopping\n- [ ] Buy milk besok !high 35k #food #home\n'
      '```\n- [ ] not a task\n```',
    );

    final item = await only();
    expect(item.title, 'Buy milk');
    expect(item.priority, Priority.high);
    expect(item.dueDate, const LocalDate(2026, 11, 26));
    expect(item.linkedAmount, const Rupiah(35000));
    expect(item.linkedCategoryId, isNotNull); // #food, as in the capture bar
    expect(item.tagIds, hasLength(1)); // #home
    expect(item.sourceNoteId, noteId);
    expect(item.sourceBlockId, matches(r'^t[0-9a-z]{6}$'));
    expect(
      out,
      'Shopping\n- [ ] Buy milk ^${item.sourceBlockId}\n'
      '```\n- [ ] not a task\n```',
    );
    expect(await body(), out);
    expect(reminders.alarms.keys, [item.notifId]);

    // Saving again changes nothing.
    expect(await save(out), out);
    expect(await only(), item);
  });

  test('new line: a time schedules it; unknown words stay', () async {
    await save('- [ ] note: call @john jam 14\n- [ ] \n- [ ] besok');
    final item = await only();
    expect(item.title, 'note: call @john');
    expect(item.scheduledStart, DateTime(2026, 11, 25, 14).toUtc());
    expect(await body(), endsWith('\n- [ ] \n- [ ] besok'));
  });

  test('changed text: renames, and new date words are consumed once', () async {
    final out = await milk();
    final id = idOf(out);

    final renamed = await save('- [ ] Buy oat milk 2 ^$id');
    expect(renamed, '- [ ] Buy oat milk 2 ^$id');
    expect((await only()).title, 'Buy oat milk 2');

    final dated = await save('- [ ] Buy oat milk 2 besok !low 5k ^$id');
    expect(dated, '- [ ] Buy oat milk 2 5k ^$id');
    final item = await only();
    expect(item.title, 'Buy oat milk 2 5k');
    expect(item.dueDate, const LocalDate(2026, 11, 26));
    expect(item.priority, Priority.low);
    expect(item.linkedAmount, isNull);
    expect(item.notifId, isNotNull);
    expect(reminders.alarms.keys, [item.notifId]);
  });

  test('changed text: date words already in the title stay', () async {
    final id = idOf(await milk());
    await items.edit(
      (await only()).id,
      const ActionItemInput(title: 'Review monday report'),
    );
    await save('- [ ] Review monday reports ^$id');
    final item = await only();
    expect(item.title, 'Review monday reports');
    expect(item.dueDate, isNull);
  });

  test('[ ] to [x] completes; a bill goes to pending', () async {
    final out = await save('- [ ] Buy milk\n- [ ] Internet 350k');
    await save(out.replaceAll('[ ]', '[x]'));

    final done = await all();
    expect(done.map((i) => i.status), everyElement(ActionStatus.done));
    expect(done.map((i) => i.completedAt), everyElement(isNotNull));
    // By title: items made in the same millisecond come back in any order.
    ActionItem named(String title) => done.singleWhere((i) => i.title == title);
    expect(named('Buy milk').billStatus, isNull);
    expect(named('Internet').billStatus, BillStatus.pending);
  });

  test('a #bill line that is new and ticked is pending', () async {
    await save('- [x] Water #bill');
    expect((await only()).billStatus, BillStatus.pending);
  });

  test('[x] to [ ] reopens', () async {
    final out = await save('- [x] Tax besok');
    expect(reminders.alarms, isEmpty);

    await save(out.replaceFirst('[x]', '[ ]'));
    final item = await only();
    expect(item.status, ActionStatus.open);
    expect(item.completedAt, isNull);
    expect(reminders.alarms.keys, [item.notifId]);
  });

  test('removed line soft-deletes; a reappearing one undeletes', () async {
    final out = await save('- [ ] Tax besok');
    final before = await only();

    await save('nothing');
    expect((await only()).isDeleted, isTrue);
    expect(reminders.alarms, isEmpty);

    // Undo or paste brings the same item back.
    expect(await save(out), out);
    final after = await only();
    expect(after.isDeleted, isFalse);
    expect(after.id, before.id);
    expect(reminders.alarms.keys, [before.notifId]);
  });

  test('a token pasted into another note gets a fresh one', () async {
    final out = await milk();
    final other = (await h.notes.create(const NoteInput())).id;

    final pasted = await sync.onNoteSaved(other, out);
    expect(idOf(pasted), isNot(idOf(out)));
    expect((await all(other)).single.title, 'Buy milk');
    expect((await only()).isDeleted, isFalse);

    // Copied within one note, the second line is new too.
    final twice = await save('$out\n$out');
    expect(await all(), hasLength(2));
    expect(twice.split('\n').first, out);
    expect(twice.split('\n').last, isNot(out));
  });

  test('the line being typed is left alone', () async {
    final out = await milk();
    final id = idOf(out);

    // Its brackets are half typed: the item must survive.
    final typing = '- [x Buy milk ^$id\n- [ ] Egg\n- [ ] Brea';
    final stored = await sync.onNoteSaved(noteId, typing, skipLine: 0);
    expect(stored.split('\n').first, '- [x Buy milk ^$id');
    expect((await all()).map((i) => i.isDeleted), everyElement(isFalse));

    final second = await sync.onNoteSaved(
      noteId,
      '$stored\n- [ ] Jam',
      skipLine: 3,
    );
    expect(second.split('\n').last, '- [ ] Jam');
    expect(await all(), hasLength(3));
  });

  test('done, reopened and renamed in Tasks rewrite the line', () async {
    final out = await save('Top\n- [ ] Buy milk\nBottom');
    final id = (await only()).id;
    final block = (await only()).sourceBlockId;

    await items.complete(id);
    expect(await body(), 'Top\n- [x] Buy milk ^$block\nBottom');
    await items.reopen(id);
    expect(await body(), out);
    await items.edit(id, const ActionItemInput(title: 'Buy tea besok'));
    expect(await body(), 'Top\n- [ ] Buy tea besok ^$block\nBottom');

    // The rewritten line is not a new rename: nothing is consumed.
    await save(await body());
    expect((await only()).title, 'Buy tea besok');
    expect((await only()).dueDate, isNull);
  });

  test('confirming or skipping a bill ticks its line', () async {
    await save('- [ ] Internet 350k\n- [ ] Water 5k');
    final [net, water] = await all();

    await bills.confirm(net.id, (await bills.draftFor(net))!);
    await bills.skip(water.id);
    expect(parseChecklist(await body()).map((l) => l.checked), [true, true]);
  });

  test('deleted in Tasks removes the line; Undo puts it back', () async {
    final out = await save('Top\n- [ ] Buy milk\nBottom');
    final id = (await only()).id;

    await items.delete(id);
    expect(await body(), 'Top\nBottom');
    await items.restore(id);
    expect(await body(), out);
    expect((await only()).isDeleted, isFalse);

    // The only line of a note.
    await save(await milk());
    final lone = (await all()).last.id;
    final text = await body();
    await items.delete(lone);
    await items.restore(lone);
    expect(await body(), text);
  });

  test('rescheduled in Tasks leaves the text unchanged', () async {
    final out = await milk();
    await items.schedule((await only()).id, DateTime.utc(2026, 11, 27, 2));
    expect(await body(), out);
  });

  test('a write-back flushes the open editor first', () async {
    final id = idOf(await milk());
    var flushed = 0;
    final detach = sync.attachEditor(noteId, () async {
      flushed++;
      await save('- [ ] Buy milk ^$id\ntyped just now');
    });

    await items.complete((await only()).id);
    expect(flushed, 1);
    expect(await body(), '- [x] Buy milk ^$id\ntyped just now');

    detach();
    await items.reopen((await only()).id);
    expect(flushed, 1);
  });

  test('one transaction: a failed save leaves no item behind', () async {
    await expectLater(
      syncOn(_FailingSave(h.notes)).onNoteSaved(noteId, '- [ ] Buy milk'),
      throwsA(isA<StorageFailure>()),
    );
    expect(await all(), isEmpty);
    expect(reminders.alarms, isEmpty);

    // The same on a write-back: the item stays open.
    final stored = await milk();
    final failing = ItemService(
      items: h.items,
      tags: h.tags,
      transactions: h.transactions,
      settings: h.settings,
      reminders: reminders,
      unitOfWork: h.unitOfWork,
      clock: const FixedClock(),
      notes: syncOn(_FailingSave(h.notes)),
    );
    await expectLater(
      failing.complete((await only()).id),
      throwsA(isA<StorageFailure>()),
    );
    expect((await only()).status, ActionStatus.open);
    expect(await body(), stored);
  });
}
