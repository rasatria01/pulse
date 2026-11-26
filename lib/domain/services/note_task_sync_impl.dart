import 'dart:math';

import 'package:collection/collection.dart';

import '../../core/clock.dart';
import '../../core/rupiah.dart';
import '../entities/action_item.dart';
import '../entities/tag.dart';
import '../parser/capture_parser.dart';
import '../parser/parse_result.dart';
import '../repositories/action_item_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';
import 'checklist.dart';
import 'item_service.dart';
import 'note_task_sync.dart';
import 'reminder_scheduler.dart';
import 'unit_of_work.dart';

/// PRD 9.2. Uses the repositories, not ItemService: ItemService calls back here.
class DefaultNoteTaskSync implements NoteTaskSync {
  DefaultNoteTaskSync({
    required this._notes,
    required this._items,
    required this._tags,
    required this._wallets,
    required this._categories,
    required this._transactions,
    required this._settings,
    required this._reminders,
    required this._unitOfWork,
    required this._clock,
    Random? random,
  }) : _random = random ?? Random();

  final NoteRepository _notes;
  final ActionItemRepository _items;
  final TagRepository _tags;
  final WalletRepository _wallets;
  final CategoryRepository _categories;
  final TransactionRepository _transactions;
  final SettingsRepository _settings;
  final ReminderScheduler _reminders;
  final UnitOfWork _unitOfWork;
  final Clock _clock;
  final Random _random;

  final _editors = <String, Set<Future<void> Function()>>{};

  /// Lines taken out by a delete in Tasks, by item id, for its Undo.
  final _removed = <String, ({int index, String line})>{};

  @override
  void Function() attachEditor(String noteId, Future<void> Function() flush) {
    (_editors[noteId] ??= {}).add(flush);
    return () => _editors[noteId]?.remove(flush);
  }

  @override
  Future<void> flushEditor(String noteId) async {
    for (final flush in [...?_editors[noteId]]) {
      await flush();
    }
  }

  @override
  Future<String> onNoteSaved(
    String noteId,
    String body, {
    int? skipLine,
  }) async {
    final lines = parseChecklist(body);
    // Outside the transaction: a watched query must not run inside one.
    final tags = lines.any((l) => l.checked)
        ? await _tags.watchAll().first
        : const <Tag>[];
    final context = ParseContext(
      _clock.nowLocal(),
      await _wallets.refs(),
      await _categories.refs(),
    );
    final changed = <ActionItem>[];
    final deleted = <int>[];

    final stored = await _unitOfWork.run(() async {
      final known = {
        for (final item in await _items.findBySourceNote(
          noteId,
          includeDeleted: true,
        ))
          item.sourceBlockId!: item,
      };
      // The line still being typed keeps its item, whatever it looks like now,
      // and so does a line that only an unclosed fence has hidden.
      final present = <String>{
        if (skipLine != null) ...blockIdsIn(body.split('\n')[skipLine]),
        ...blockIdsInOpenFence(body),
      };
      var out = body;
      final checked = {for (final l in lines) l.index: l.checked};
      for (final MapEntry(key: index, value: found) in damagedBlockIds(
        body,
        known.keys.toSet(),
      ).entries) {
        if (index == skipLine) {
          present.add(found.blockId);
          continue;
        }
        out = rewriteChecklistLine(
          out,
          index,
          checked: checked[index]!,
          title: found.title,
          blockId: found.blockId,
        );
      }

      final repaired = parseChecklist(out);
      final taken = {...known.keys, for (final l in repaired) ?l.token};
      // Copied lines share an id. It goes to the line that still looks like the
      // item, not simply the first. While the copy being typed is one of them,
      // none can be told apart yet.
      final owner = <String, int>{};
      final waiting = <String>{};
      final shared = groupBy(
        repaired.where((l) => l.token != null),
        (l) => l.token!,
      );
      for (final MapEntry(key: id, value: copies) in shared.entries) {
        if (copies.length > 1 && copies.any((l) => l.index == skipLine)) {
          waiting.add(id);
          continue;
        }
        final item = known[id];
        owner[id] =
            (copies.firstWhereOrNull(
                      (l) =>
                          l.title == item?.title &&
                          l.checked == (item?.status == ActionStatus.done),
                    ) ??
                    copies.firstWhereOrNull((l) => l.title == item?.title) ??
                    copies.first)
                .index;
      }

      for (final line in repaired) {
        if (line.index == skipLine || waiting.contains(line.token)) continue;
        var title = line.title;
        var blockId = owner[line.token] == line.index ? line.token : null;
        final item = known[blockId];
        if (item != null) {
          final (updated, shown) = await _apply(item, line, context, tags);
          if (updated != null) changed.add(updated);
          title = shown;
        } else {
          // New: no token, or one that belongs to another note or line.
          final parsed = _read(line.title, context);
          if (parsed.title.isEmpty) continue;
          title = parsed.title;
          blockId = generateBlockId(_random, taken);
          taken.add(blockId);
          changed.add(
            await _create(noteId, blockId, parsed, line.checked, tags),
          );
        }
        present.add(blockId!);
        if (item == null || title != line.title) {
          out = rewriteChecklistLine(
            out,
            line.index,
            checked: line.checked,
            title: title,
            blockId: blockId,
          );
        }
      }

      for (final item in known.values) {
        if (item.isDeleted || present.contains(item.sourceBlockId)) continue;
        await _items.softDelete(item.id);
        if (item.notifId case final id?) deleted.add(id);
      }
      await _notes.saveBody(noteId, out);
      return out;
    });

    for (final id in deleted) {
      await quietly(() => _reminders.cancel(id));
    }
    for (final item in changed) {
      await syncReminder(_reminders, item);
    }
    return stored;
  }

  @override
  Future<void> onItemChanged(ActionItem item) async {
    final noteId = item.sourceNoteId;
    final blockId = item.sourceBlockId;
    if (noteId == null || blockId == null) return;
    final note = await _notes.find(noteId);
    if (note == null) return;
    final line = parseChecklist(note.body)
        .firstWhereOrNull((l) => l.blockId == blockId);
    final done = item.status == ActionStatus.done;
    var body = note.body;

    if (item.isDeleted) {
      if (line == null) return;
      _removed[item.id] = (
        index: line.index,
        line: body.split('\n')[line.index],
      );
      body = removeChecklistLine(body, line.index);
    } else if (line == null) {
      // Undo of that delete: the line goes back where it was.
      final removed = _removed.remove(item.id);
      if (removed == null) return;
      final lines = body.isEmpty ? <String>[] : body.split('\n');
      lines.insert(min(removed.index, lines.length), removed.line);
      body = lines.join('\n');
    } else if (line.checked != done || line.title != item.title) {
      body = rewriteChecklistLine(
        body,
        line.index,
        checked: done,
        title: item.title,
        blockId: blockId,
      );
    }
    if (body != note.body) await _notes.saveBody(noteId, body);
  }

  Future<ActionItem> _create(
    String noteId,
    String blockId,
    _Read parsed,
    bool checked,
    List<Tag> tags,
  ) async {
    final draft = parsed.draft;
    final amount = draft.linkedAmount;
    final anchored = draft.scheduledStart != null || draft.dueDate != null;
    var item = await _items.create(
      ActionItemInput(
        title: parsed.title,
        priority: draft.priority,
        dueDate: draft.dueDate,
        scheduledStart: draft.scheduledStart?.toUtc(),
        scheduledEnd: draft.scheduledEnd?.toUtc(),
        notifId: anchored ? await _settings.nextNotificationId() : null,
        linkedAmount: amount == null ? null : Rupiah(amount),
        linkedWalletId: draft.linkedWalletId,
        linkedCategoryId: draft.linkedCategoryId,
        sourceNoteId: noteId,
        sourceBlockId: blockId,
        rawInput: draft.raw,
      ),
    );
    var allTags = tags;
    if (draft.tagSlugs.isNotEmpty) {
      final used = await _tags.ensure(draft.tagSlugs);
      await _tags.setTags(EntityType.actionItem, item.id, [
        for (final t in used) t.id,
      ]);
      allTags = [...tags, ...used];
      item = (await _items.find(item.id))!;
    }
    if (!checked) return item;
    return _items.update(item.id, await _checkPatch(item, true, allTags));
  }

  /// Brings [item] in line with [line]. Returns the item if it was written, and
  /// the title the line should now show.
  Future<(ActionItem?, String)> _apply(
    ActionItem item,
    ChecklistLine line,
    ParseContext context,
    List<Tag> tags,
  ) async {
    var wrote = item.isDeleted;
    if (item.isDeleted) await _items.undelete(item.id);
    var current = item.copyWith(isDeleted: false);
    var title = line.title;

    // An emptied line keeps the item's title: an item cannot have none.
    if (line.title.isNotEmpty && line.title != item.title) {
      final parsed = _read(line.title, context, oldTitle: item.title);
      var patch = ActionItemPatch(title: line.title);
      // Nothing but date words is a title, not a rename to nothing.
      if (parsed.title.isNotEmpty) {
        title = parsed.title;
        final draft = parsed.draft;
        final start = draft.scheduledStart;
        final due = draft.dueDate;
        patch = ActionItemPatch(
          title: title,
          priority: draft.priority == Priority.none ? null : draft.priority,
          dueDate: due == null ? null : (value: due),
          scheduledStart: start == null ? null : (value: start.toUtc()),
          scheduledEnd: start == null
              ? null
              : (value: draft.scheduledEnd?.toUtc()),
        );
      }
      current = await _items.update(item.id, patch);
      wrote = true;
    }

    if (line.checked != (current.status == ActionStatus.done)) {
      current = await _items.update(
        item.id,
        await _checkPatch(current, line.checked, tags),
      );
      wrote = true;
    }
    if (!wrote) return (null, title);
    final anchored = current.scheduledStart != null || current.dueDate != null;
    if (anchored && current.notifId == null) {
      current = await _items.update(
        item.id,
        ActionItemPatch(notifId: await _settings.nextNotificationId()),
      );
    }
    return (current, title);
  }

  /// Ticking a bill leaves it pending: there is no sheet here (PRD 9.1).
  Future<ActionItemPatch> _checkPatch(
    ActionItem item,
    bool checked,
    List<Tag> tags,
  ) async {
    if (!checked) {
      return const ActionItemPatch(
        status: ActionStatus.open,
        completedAt: (value: null),
        billStatus: (value: null),
      );
    }
    BillStatus? bill;
    if (isBill(item, tags)) {
      bill = await _transactions.findBySourceActionItem(item.id) == null
          ? BillStatus.pending
          : BillStatus.recorded;
    }
    return ActionItemPatch(
      status: ActionStatus.done,
      completedAt: (value: _clock.nowUtc()),
      billStatus: (value: bill),
    );
  }
}

typedef _Read = ({String title, ActionItemDraft draft});

const _dateKinds = {
  TokenKind.date,
  TokenKind.time,
  TokenKind.timeRange,
  TokenKind.priority,
};
const _newLineKinds = {
  ..._dateKinds,
  TokenKind.amount,
  TokenKind.tag,
  TokenKind.category,
  TokenKind.wallet,
};
final _word = RegExp(r'\S+');
final _notePrefix = RegExp(r'^(note:|/)', caseSensitive: false);

/// Runs the capture parser on a line's text and cuts out the words it consumed.
/// With [oldTitle] (an existing line) only newly typed date, time and priority
/// words count.
_Read _read(String text, ParseContext context, {String? oldTitle}) {
  // "note:" and "/" mean something to the capture bar, not on a checklist line.
  final escape = _notePrefix.hasMatch(text) ? r'\' : '';
  final input = '$escape$text';
  var seen = input;
  if (oldTitle != null) {
    final old = {for (final m in _word.allMatches(oldTitle)) m[0]!};
    // Blanked at the same length, so token offsets still fit [input].
    seen = input.replaceAllMapped(
      _word,
      (m) => old.contains(m[0]) ? '_' * m[0]!.length : m[0]!,
    );
  }
  final draft = parseCapture(
    seen,
    context,
    overrides: const CaptureOverrides(kind: CaptureKind.actionItem),
  ) as ActionItemDraft;

  final kinds = oldTitle == null ? _newLineKinds : _dateKinds;
  final kept = StringBuffer();
  var at = 0;
  for (final token in draft.tokens) {
    // An unknown @mention or a broken amount stays as text.
    if (!kinds.contains(token.kind) || token.value == null) continue;
    kept.write(input.substring(at, token.start));
    at = token.end;
  }
  if (at == 0) return (title: text, draft: draft);
  kept.write(input.substring(at));
  var title = kept.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (escape.isNotEmpty && title.startsWith(escape)) title = title.substring(1);
  return (title: title, draft: draft);
}
