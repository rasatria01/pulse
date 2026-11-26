// A task line's token survives typing, copying and code fences.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/domain/services/note_task_sync_impl.dart';
import 'package:pulse/features/notes/markdown_editing.dart';

import '../data/support.dart';
import 'planner_services_test.dart' show FakeScheduler;

/// '|' marks the cursor; two of them a selection.
TextEditingValue _v(String marked) {
  final start = marked.indexOf('|');
  final end = marked.lastIndexOf('|');
  return TextEditingValue(
    text: marked.replaceAll('|', ''),
    selection: TextSelection(
      baseOffset: start,
      extentOffset: end == start ? start : end - 1,
    ),
  );
}

String _marked(TextEditingValue v) =>
    v.text.replaceRange(v.selection.start, v.selection.start, '|');

String _edit(String before, String after) =>
    _marked(keepBlockIds(_v(before), _v(after)));

const _t = '^tabc123';

void main() {
  group('typing', () {
    test('at the end of a task line goes into the title', () {
      expect(
        _edit('- [ ] Milk $_t|', '- [ ] Milk ${_t}s|'),
        '- [ ] Milks| $_t',
      );
      // Equal to the token's last character.
      expect(
        _edit('- [ ] Milk $_t|', '- [ ] Milk ${_t}3|'),
        '- [ ] Milk3| $_t',
      );
      expect(
        _edit('- [ ] Milk ^tab|c123', '- [ ] Milk ^tabX|c123'),
        '- [ ] MilkX| $_t',
      );
      expect(_edit('- [ ] $_t|', '- [ ] ${_t}M|'), '- [ ] M| $_t');
    });

    test('a space or new line after the token is left alone', () {
      expect(_edit('- [ ] a $_t|', '- [ ] a $_t |'), '- [ ] a $_t |');
      expect(_edit('- [ ] a $_t|', '- [ ] a $_t\n|'), '- [ ] a $_t\n|');
      expect(_edit('- [ ] a| $_t', '- [ ] a\n| $_t'), '- [ ] a $_t\n|');
    });

    test('backspace at the end removes title characters, never the token', () {
      expect(_edit('- [ ] Milk $_t|', '- [ ] Milk ^tabc12|'), '- [ ] Mil| $_t');
      expect(_edit('- [ ] a $_t|', '- [ ] a ^tabc12|'), '- [ ] | $_t');
      expect(_edit('- [ ] $_t|', '- [ ] ^tabc12|'), '- [ ] $_t|');
      // The separating space.
      expect(_edit('- [ ] ab |$_t', '- [ ] ab|$_t'), '- [ ] a| $_t');
      // Forward delete at the end of the title.
      expect(_edit('- [ ] ab| $_t', '- [ ] ab|$_t'), '- [ ] ab| $_t');
    });

    test('a selection reaching into the token stops before it', () {
      expect(
        _edit('- [ ] Mi|lk ^tab|c123\nx', '- [ ] Mi|c123\nx'),
        '- [ ] Mi| $_t\nx',
      );
      expect(
        _edit('- [ ] Mi|lk $_t\nnext| line', '- [ ] Mi| line'),
        '- [ ] Mi| $_t line',
      );
    });

    test('the whole line takes its token with it', () {
      expect(_edit('a\n|- [ ] b $_t|\nc', 'a\n|\nc'), 'a\n|\nc');
      expect(_edit('a|\n- [ ] b $_t|\nc', 'a|\nc'), 'a|\nc');
    });

    test('other lines are untouched', () {
      expect(_edit('see $_t|', 'see ^tabc12|'), 'see ^tabc12|');
      expect(_edit('- [ ] Mil|k $_t', '- [ ] Milx|k $_t'), '- [ ] Milx|k $_t');
    });

    test('the toolbar works before the token', () {
      expect(
        applyMarkdown(
          outsideBlockIds(_v('- [ ] a $_t|')),
          MarkdownAction.bold,
        ).text,
        '- [ ] a**** $_t',
      );
    });
  });

  group('sync', () {
    late Harness h;
    late DefaultNoteTaskSync sync;
    late String noteId;
    late ActionItem item;
    late String token;

    setUp(() async {
      h = Harness();
      sync = DefaultNoteTaskSync(
        notes: h.notes,
        items: h.items,
        tags: h.tags,
        wallets: h.wallets,
        categories: h.categories,
        transactions: h.transactions,
        settings: h.settings,
        reminders: FakeScheduler(),
        unitOfWork: h.unitOfWork,
        clock: const FixedClock(),
      );
      noteId = (await h.notes.create(const NoteInput())).id;
      final body = await sync.onNoteSaved(noteId, '- [ ] Rent 50k besok');
      item = (await h.items.findBySourceNote(noteId)).single;
      token = '^${item.sourceBlockId}';
      expect(body, '- [ ] Rent $token');
      expect(item.linkedAmount, const Rupiah(50000));
    });
    tearDown(() => h.db.close());

    Future<List<ActionItem>> all() =>
        h.items.findBySourceNote(noteId, includeDeleted: true);

    /// The one item, still itself: not deleted and remade.
    Future<ActionItem> same() async {
      final found = (await all()).single;
      expect(found.id, item.id);
      expect(found.isDeleted, isFalse);
      expect(found.linkedAmount, item.linkedAmount);
      expect(found.dueDate, item.dueDate);
      return found;
    }

    test('a token cut short is repaired', () async {
      for (final cut in [1, 3]) {
        final body = await sync.onNoteSaved(
          noteId,
          '- [ ] Rent ${token.substring(0, token.length - cut)}',
        );
        expect(body, '- [ ] Rent $token');
        expect((await same()).title, 'Rent');
      }
    });

    test('characters typed onto a token join the title', () async {
      final body = await sync.onNoteSaved(noteId, '- [ ] Rent ${token}al');
      expect(body, '- [ ] Rental $token');
      expect((await same()).title, 'Rental');
    });

    test('a damaged token on the line being typed keeps the item', () async {
      final typed = '- [ ] Rent ${token.substring(0, token.length - 1)}';
      expect(await sync.onNoteSaved(noteId, typed, skipLine: 0), typed);
      await same();
    });

    test('a copy above the original does not take its identity', () async {
      final copied = '- [ ] Rent flat $token\n- [ ] Rent $token';
      final body = await sync.onNoteSaved(noteId, copied);
      final lines = body.split('\n');
      expect(lines[1], '- [ ] Rent $token');
      expect(lines[0], isNot(contains(token)));
      final items = await all();
      expect(items, hasLength(2));
      final original = items.singleWhere((i) => i.id == item.id);
      expect(original.title, 'Rent');
      expect(original.linkedAmount, item.linkedAmount);
    });

    test('the checked state also tells copies apart', () async {
      final body = await sync.onNoteSaved(
        noteId,
        '- [x] Rent $token\n- [ ] Rent $token',
      );
      expect(body.split('\n')[1], '- [ ] Rent $token');
      final original = (await all()).singleWhere((i) => i.id == item.id);
      expect(original.status, ActionStatus.open);
    });

    test('nothing is re-registered while a copy is being typed', () async {
      final copied = '- [ ] Rent fl $token\n- [ ] Rent $token';
      expect(await sync.onNoteSaved(noteId, copied, skipLine: 0), copied);
      expect((await same()).title, 'Rent');
    });

    test('an unclosed fence above keeps the tasks', () async {
      final fenced = '```\n- [ ] Rent $token';
      expect(await sync.onNoteSaved(noteId, fenced), fenced);
      await same();
      // Closed, the line is code and the task is gone, as before.
      await sync.onNoteSaved(noteId, '$fenced\n```');
      expect((await all()).single.isDeleted, isTrue);
    });
  });
}
