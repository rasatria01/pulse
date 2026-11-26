import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/features/search/search_screen.dart';
import 'package:pulse/features/search/search_strings.dart';
import 'package:pulse/features/tasks/tasks_screen.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

import 'support.dart';

/// Awaits database work while the test's fake clock turns.
Future<void> _db(WidgetTester tester, Future<Object?> work) async {
  var done = false;
  final result = work.whenComplete(() => done = true);
  for (var i = 0; !done && i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue, reason: 'database work did not finish');
  await result;
}

void main() {
  testWidgets('debounced prefix words, #tag, type chips; a tap opens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShadApp)),
      listen: false,
    );
    final items = container.read(itemServiceProvider);
    await _db(
      tester,
      items.create(
        const ActionItemInput(title: 'Water the garden'),
        tagSlugs: ['home'],
      ),
    );
    await _db(
      tester,
      items.create(const ActionItemInput(title: 'Garage keys')),
    );
    await _db(
      tester,
      container
          .read(noteRepositoryProvider)
          .create(const NoteInput(title: 'Garden plan', body: 'beds and soil')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is PButton && w.semanticLabel == PulseStrings.search,
      ),
    );
    await tester.pumpAndSettle();

    Future<void> type(String text) async {
      await tester.enterText(find.byType(EditableText), text);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(EditableText), 'gar');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Garage keys'), findsNothing); // still debouncing
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Water the garden'), findsOneWidget);
    expect(find.text('Garage keys'), findsOneWidget);
    expect(find.text('Garden plan'), findsOneWidget);
    // Grouped: tasks above notes.
    expect(
      tester.getTopLeft(find.text('Garage keys')).dy,
      lessThan(tester.getTopLeft(find.text('Garden plan')).dy),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('type-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('type-note')));
    await tester.pumpAndSettle();
    expect(find.text('Garden plan'), findsOneWidget);
    expect(find.text('Garage keys'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('type-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('type-all')));
    await tester.pumpAndSettle();

    await type('gar #home');
    expect(find.text('Water the garden'), findsOneWidget);
    expect(find.text('Garage keys'), findsNothing);
    expect(find.text('Garden plan'), findsNothing);

    await type('#hom'); // a tag is exact, not a prefix
    expect(find.text(SearchStrings.noResults), findsOneWidget);

    await type('water');
    await tester.tap(find.text('Water the garden'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(find.byType(TasksScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
