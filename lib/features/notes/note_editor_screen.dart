import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../core/local_date.dart';
import '../../core/routes.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/services/checklist.dart';
import '../../ui/planner/planner_format.dart';
import '../../ui/widgets/widgets.dart';
import 'markdown_editing.dart';
import 'note_merge.dart';
import 'note_preview.dart';
import 'notes_strings.dart';

const _autosaveAfter = Duration(milliseconds: 500);

const _toolbar = [
  (MarkdownAction.heading, LucideIcons.heading, NotesStrings.heading),
  (MarkdownAction.bold, LucideIcons.bold, NotesStrings.bold),
  (MarkdownAction.italic, LucideIcons.italic, NotesStrings.italic),
  (MarkdownAction.checklist, LucideIcons.listChecks, NotesStrings.checklist),
  (MarkdownAction.code, LucideIcons.code, NotesStrings.code),
];

/// The day of a scratchpad id, or null for any other id.
LocalDate? _dayOf(String id) {
  if (!id.startsWith(Routes.dailyNotePrefix)) return null;
  try {
    return LocalDate.parse(id.substring(Routes.dailyNotePrefix.length));
  } on FormatException {
    return null;
  }
}

/// PRD F5. [id] is a note id, [Routes.newNoteId], or a scratchpad id.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _controller = MarkdownController();
  final _focus = FocusNode();

  // Read once: the last save runs after ref is gone.
  late final NoteRepository _notes;
  late final NoteTaskSync _sync;
  late final AppLifecycleListener _lifecycle;
  void Function()? _detach;
  late final LocalDate? _day = _dayOf(widget.id);

  /// Null until the note exists.
  String? _noteId;

  /// The body as stored, and the editor's text, which outlives the controller.
  String _stored = '';
  TextEditingValue _value = TextEditingValue.empty;

  Timer? _debounce;
  Future<void> _queue = Future.value();

  /// The checklist line the last save left alone because it was being typed.
  int? _deferred;
  bool _unsynced = false;
  bool _loaded = false;
  bool _gone = false;
  bool _closed = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _notes = ref.read(noteRepositoryProvider);
    _sync = ref.read(noteTaskSyncProvider);
    _lifecycle = AppLifecycleListener(onHide: _flush, onPause: _flush);
    _controller.addListener(_changed);

    final day = _day;
    if (widget.id == Routes.newNoteId) {
      _loaded = true;
    } else if (day != null) {
      ref.listenManual(
        dailyNoteProvider(day),
        _onStored,
        fireImmediately: true,
      );
    } else {
      ref.listenManual(
        noteProvider(widget.id),
        _onStored,
        fireImmediately: true,
      );
    }
  }

  @override
  void dispose() {
    _closed = true;
    _lifecycle.dispose();
    // Leaving the editor saves; the write outlives the widget.
    _flush().whenComplete(() => _detach?.call());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onStored(AsyncValue<Note?>? _, AsyncValue<Note?> next) {
    if (!next.hasValue) return;
    final note = next.value;
    if (_noteId != null) {
      // Something changed the row: our own save, or a write-back.
      _enqueue(_pull);
      return;
    }
    if (note != null && _value.text.isEmpty) {
      _adopt(note);
      _value = TextEditingValue(
        text: note.body,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _controller.value = _value;
      // Lines still without an item, from quick capture or a killed app.
      if (parseChecklist(note.body).any((l) => l.blockId == null)) {
        _unsynced = true;
        _schedule();
      }
    }
    if (!_loaded) {
      setState(() {
        _loaded = true;
        _gone = note == null && _day == null;
      });
    }
  }

  void _adopt(Note note) {
    _noteId = note.id;
    _stored = note.body;
    _detach = _sync.attachEditor(note.id, _flush);
    // A new note has no row to watch until now.
    if (widget.id == Routes.newNoteId && !_closed) {
      ref.listenManual(noteProvider(note.id), _onStored);
    }
  }

  void _changed() {
    final old = _value;
    _value = _controller.value;
    if (_value.text != old.text) {
      // The first keystroke creates the note; the rest waits for a pause.
      if (_noteId == null) _enqueue(_create);
      _schedule();
    } else if (_deferred != null && _cursorLine() != _deferred) {
      _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(_autosaveAfter, () => _enqueue(_save));
  }

  /// Saves everything now, the line being typed included.
  Future<void> _flush() {
    _debounce?.cancel();
    return _enqueue(() => _save(all: true));
  }

  /// One write at a time, in order. Nothing may leave the queue failed, or no
  /// later save would run.
  Future<void> _enqueue(Future<void> Function() job) =>
      _queue = _queue.then((_) async {
        try {
          await job();
        } catch (e, s) {
          _report(e, s);
          _toast(NotesStrings.saveFailed);
        }
      });

  void _report(Object error, StackTrace stack) {
    if (error is AppFailure) return;
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
  }

  int? _cursorLine() {
    if (_closed || !_focus.hasFocus || !_value.selection.isValid) return null;
    final before = _value.text.substring(0, _value.selection.extentOffset);
    return '\n'.allMatches(before).length;
  }

  Future<void> _create() async {
    if (_noteId != null || _value.text.isEmpty) return;
    final day = _day;
    _adopt(
      day != null
          ? await _notes.ensureDaily(day)
          : await _notes.create(const NoteInput()),
    );
    await _save();
  }

  Future<void> _save({bool all = false}) async {
    if (_gone) return;
    // A failed create is tried again here.
    if (_noteId == null) return _value.text.isEmpty ? null : _create();
    if (!await _pull()) return;
    final text = _value.text;
    if (text == _stored && !_unsynced) return;

    var skip = all ? null : _cursorLine();
    // Only a checklist line, or one that had an item, is worth leaving.
    if (skip != null &&
        blockIdsIn(text.split('\n')[skip]).isEmpty &&
        !parseChecklist(text).any((l) => l.index == skip)) {
      skip = null;
    }
    String stored;
    try {
      stored = await _sync.onNoteSaved(_noteId!, text, skipLine: skip);
    } catch (e, s) {
      // The words matter more than the sync.
      _report(e, s);
      await _notes.saveBody(_noteId!, text);
      stored = text;
      _toast(NotesStrings.syncFailed);
    }
    _deferred = skip;
    _unsynced = skip != null;
    _absorb(text, stored);
  }

  /// Takes in a write made outside this editor. False once the note is deleted.
  Future<bool> _pull() async {
    final note = await _notes.find(_noteId!);
    if (note == null) return false;
    if (note.body != _stored) _absorb(_stored, note.body);
    return true;
  }

  /// Applies the change [base] -> [theirs] to the text, cursor in place.
  void _absorb(String base, String theirs) {
    _stored = theirs;
    final mine = _value.text;
    final merged = mergeBody(base, mine, theirs);
    if (merged == mine) return;
    final selection = _value.selection;
    // Set first: this is not typing, so the listener must not schedule a save.
    _value = TextEditingValue(
      text: merged,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: mapOffset(mine, merged, selection.baseOffset),
              extentOffset: mapOffset(mine, merged, selection.extentOffset),
            )
          : selection,
    );
    if (_closed) return;
    _controller.value = _value;
    if (_preview) setState(() {});
  }

  void _toast(String message) {
    if (_closed || !mounted) return;
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  void _apply(MarkdownAction action) {
    _focus.requestFocus();
    _controller.value = applyMarkdown(_controller.value, action);
  }

  Future<void> _togglePreview() async {
    await _flush();
    if (!mounted) return;
    final id = _noteId;
    if (id != null) ref.invalidate(noteItemsProvider(id));
    setState(() => _preview = !_preview);
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.notes);

  Future<void> _delete() async {
    await _flush();
    if (!mounted) return;
    final id = _noteId;
    if (id == null) return _close();
    final root = Navigator.of(context, rootNavigator: true).context;
    final notes = _notes;
    try {
      await notes.softDelete(id);
    } on AppFailure {
      _toast(NotesStrings.saveFailed);
      return;
    }
    _gone = true;
    if (!root.mounted) return;
    _close();
    showPSnackbar(
      root,
      message: NotesStrings.deleted,
      onUndo: () async {
        try {
          await notes.undelete(id);
        } on AppFailure {
          // A new scratchpad may have taken this day's place.
          if (!root.mounted) return;
          ShadToaster.of(root).show(
            const ShadToast(description: Text(NotesStrings.restoreFailed)),
          );
        }
      },
    );
  }

  Widget _editor(ShadColorScheme colors) => Column(
    children: [
      // The field grows with its text and this view scrolls: ShadInput cannot
      // fill a fixed height itself.
      Expanded(
        child: LayoutBuilder(
          builder: (context, space) => SingleChildScrollView(
            child: ConstrainedBox(
              // A tap below a short note still lands in the field.
              constraints: BoxConstraints(minHeight: space.maxHeight),
              child: ShadInput(
                key: const ValueKey('note-body'),
                controller: _controller,
                focusNode: _focus,
                autofocus: _noteId == null,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                style: PulseText.body.copyWith(color: colors.foreground),
                placeholder: const Text(NotesStrings.writeSomething),
                decoration: ShadDecoration.none,
                padding: const EdgeInsets.symmetric(horizontal: PulseSpace.s4),
                alignment: Alignment.topLeft,
                placeholderAlignment: Alignment.topLeft,
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
            ),
          ),
        ),
      ),
      // In the field's tap region, so a tap keeps the keyboard.
      TextFieldTapRegion(
        child: ExcludeFocus(
          child: ColoredBox(
            color: colors.card,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (action, icon, label) in _toolbar)
                  PButton.ghost(
                    icon: icon,
                    semanticLabel: label,
                    onPressed: () => _apply(action),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final today = ref.watch(todayProvider);
    final day = _day;
    final ready = _loaded && !_gone;

    return PScreen(
      title: day == null
          ? NotesStrings.note
          : NotesStrings.scratchpad(dayLabel(day, today)),
      onBack: _close,
      actions: [
        if (ready) ...[
          PButton.ghost(
            icon: _preview ? LucideIcons.pencil : LucideIcons.eye,
            semanticLabel: _preview ? NotesStrings.edit : NotesStrings.preview,
            onPressed: _togglePreview,
          ),
          PButton.ghost(
            icon: LucideIcons.trash2,
            semanticLabel: NotesStrings.delete,
            onPressed: _delete,
          ),
        ],
      ],
      child: !_loaded
          ? const SizedBox.shrink()
          : _gone
          ? const EmptyState(
              icon: LucideIcons.stickyNote,
              title: NotesStrings.notFound,
            )
          : _preview
          ? NotePreview(body: _value.text, noteId: _noteId)
          : _editor(colors),
    );
  }
}
