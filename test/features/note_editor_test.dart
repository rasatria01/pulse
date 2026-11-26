// The editor in the whole app: autosave, scratchpad, write-back, delete.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/routes.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/features/notes/note_editor_screen.dart';
import 'package:pulse/features/notes/note_preview.dart';
import 'package:pulse/features/notes/notes_strings.dart';
import 'package:pulse/features/search/search_screen.dart';
import 'package:pulse/features/today/today_screen.dart';
import 'package:pulse/ui/planner/planner_strings.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

import 'support.dart';

/// Lets the real event loop turn, which drift needs between frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

Future<T> _db<T>(WidgetTester tester, Future<T> work) async {
  var done = false;
  final result = work.whenComplete(() => done = true);
  for (var i = 0; !done && i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue, reason: 'database work did not finish');
  return result;
}

Future<List<String>> _rows(
  WidgetTester tester,
  AppDatabase db,
  String column,
  String table,
) async {
  final rows = await _db(
    tester,
    db
        .customSelect(
          'SELECT $column AS v FROM $table WHERE is_deleted = 0 '
          'ORDER BY created_at, id',
        )
        .get(),
  );
  return [for (final row in rows) row.read<String>('v')];
}

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is PButton && (w.label ?? w.semanticLabel) == label,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

final _field = find.descendant(
  of: find.byType(NoteEditorScreen),
  matching: find.byType(EditableText),
);

TextEditingController _controller(WidgetTester tester) =>
    tester.widget<EditableText>(_field).controller;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await _settle(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(NoteEditorScreen)));

/// Pushes the editor the way search does.
Future<void> _push(WidgetTester tester, String id) async {
  GoRouter.of(tester.element(find.byType(TodayScreen, skipOffstage: false)))
      .push(Routes.notePath(id));
  await _settle(tester);
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 740);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  for (final mode in [ShadThemeMode.light, ShadThemeMode.dark]) {
    testWidgets('scratchpad: first keystroke, autosave, ${mode.name}', (
      tester,
    ) async {
      _phone(tester);
      final db = await pumpApp(tester, mode: mode);

      await tester.scrollUntilVisible(
        find.text(MelaStrings.noScratchpad),
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('scratchpad')));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('scratchpad')));
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      // Opening creates nothing.
      expect(await _rows(tester, db, 'body', 'notes'), isEmpty);

      await _type(tester, 'H');
      expect(await _rows(tester, db, 'kind', 'notes'), ['daily']);

      // Killed 1 s after the last keystroke: everything is already stored.
      await tester.enterText(_field, 'Hello\n- [ ] Buy milk besok\n');
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(
        (await _rows(tester, db, 'body', 'notes')).single,
        matches(r'^Hello\n- \[ \] Buy milk \^t[0-9a-z]{6}\n$'),
      );
      expect(await _rows(tester, db, 'title', 'action_items'), ['Buy milk']);
      expect(_controller(tester).text, startsWith('Hello\n- [ ] Buy milk ^t'));
      expect(await _rows(tester, db, 'daily_date', 'notes'), ['2026-11-25']);

      // Preview hides the token and shows the date.
      await _tap(tester, _button(NotesStrings.preview));
      expect(find.byType(NotePreview), findsOneWidget);
      expect(find.textContaining('^t'), findsNothing);
      expect(find.text(PlannerStrings.tomorrow), findsOneWidget);
      await _tap(tester, _button(NotesStrings.edit));

      // Back on Today the scratchpad shows, without its token.
      await _tap(tester, _button(MelaStrings.back));
      expect(find.textContaining('Hello\n- [ ] Buy milk'), findsOneWidget);
      expect(find.textContaining('^t'), findsNothing);
    });
  }

  testWidgets('the typed line waits; leaving and pausing save it', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await _push(tester, Routes.newNoteId);
    await tester.tap(_field);
    await _type(tester, '- [ ] Buy ');
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    // The body is stored, but the line is not rewritten under the cursor.
    expect(await _rows(tester, db, 'body', 'notes'), ['- [ ] Buy ']);
    expect(await _rows(tester, db, 'title', 'action_items'), isEmpty);
    expect(_controller(tester).text, '- [ ] Buy ');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await _settle(tester);
    expect(await _rows(tester, db, 'title', 'action_items'), ['Buy']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    // Leaving before the debounce fires.
    await tester.enterText(_field, '${_controller(tester).text}\nlast words');
    await _tap(tester, _button(MelaStrings.back));
    expect(find.byType(NoteEditorScreen), findsNothing);
    expect(
      (await _rows(tester, db, 'body', 'notes')).single,
      endsWith('\nlast words'),
    );
  });

  testWidgets('write-backs reach the open editor without moving the cursor', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await _push(tester, Routes.newNoteId);
    await _type(tester, 'Top\n- [ ] Buy milk\nBottom');
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);

    final items = _container(tester).read(itemServiceProvider);
    final id = (await _rows(tester, db, 'id', 'action_items')).single;
    final controller = _controller(tester);

    // Unsaved text is flushed before the write-back.
    await tester.enterText(_field, '${controller.text} more');
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    await _db(tester, items.complete(id));
    await _settle(tester);
    expect(controller.text, startsWith('Top\n- [x] Buy milk ^t'));
    expect(controller.text, endsWith('\nBottom more'));
    expect(controller.selection.extentOffset, controller.text.length);

    // The cursor above a removed line stays; Undo brings the line back.
    controller.selection = const TextSelection.collapsed(offset: 2);
    await _db(tester, items.delete(id));
    await _settle(tester);
    expect(controller.text, 'Top\nBottom more');
    expect(controller.selection.extentOffset, 2);
    await _db(tester, items.restore(id));
    await _settle(tester);
    expect(controller.text, startsWith('Top\n- [x] Buy milk ^t'));

    // A later save does not undo the write-back.
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    expect(await _rows(tester, db, 'status', 'action_items'), ['done']);
  });

  testWidgets('toolbar, delete with undo, and a push from search', (
    tester,
  ) async {
    _phone(tester);
    final db = await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );
    final note = await _db(
      tester,
      container
          .read(noteRepositoryProvider)
          .create(const NoteInput(body: 'Plans')),
    );

    GoRouter.of(tester.element(find.byType(TodayScreen))).push(Routes.search);
    await _settle(tester);
    GoRouter.of(tester.element(find.byType(SearchScreen)))
        .push(Routes.notePath(note.id));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_controller(tester).text, 'Plans');

    await _tap(tester, _button(NotesStrings.checklist));
    expect(_controller(tester).text, '- [ ] Plans');

    await _tap(tester, _button(NotesStrings.delete));
    expect(find.byType(NoteEditorScreen), findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(await _rows(tester, db, 'id', 'notes'), isEmpty);
    await _tap(tester, _button(MelaStrings.undo));
    expect(await _rows(tester, db, 'id', 'notes'), [note.id]);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a 10,000 character note opens', (tester) async {
    await pumpApp(tester);
    final body = List.generate(
      250,
      (i) => i.isEven ? '- [ ] item $i ^t${'$i'.padLeft(6, '0')}' : 'x' * 60,
    ).join('\n');
    expect(body.length, greaterThan(10000));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );
    final note = await _db(
      tester,
      container.read(noteRepositoryProvider).create(NoteInput(body: body)),
    );

    final watch = Stopwatch()..start();
    await _push(tester, note.id);
    // A debug-mode bound that only catches something quadratic; the 200 ms
    // target is a device measurement.
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(_controller(tester).text, body);
    await _tap(tester, _button(NotesStrings.preview));
    expect(find.byType(NotePreview), findsOneWidget);
  });
}
