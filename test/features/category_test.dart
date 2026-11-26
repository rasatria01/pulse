import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/features/capture/capture_sheet.dart';
import 'package:pulse/features/finance/finance_strings.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';

import 'support.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

Finder _chip(String? field, String label) => find.byWidgetPredicate(
  (w) => w is PChip && w.field == field && w.label == label,
);

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is PButton && (w.semanticLabel ?? w.label) == label,
);

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  bool up = false,
}) async {
  await tester.scrollUntilVisible(
    finder,
    up ? -150 : 150,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _settle(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PCaptureBar).first));

Future<List<Category>> _categories(WidgetTester tester) async {
  final work = _container(tester)
      .read(categoryRepositoryProvider)
      .watchAll(includeArchived: true)
      .first;
  late List<Category> result;
  await tester.runAsync(() async => result = await work);
  return result;
}

void main() {
  test('a new category gets a handle and an unused colour', () {
    expect(categorySlug('  Makan  siang! '), 'makan-siang');
    expect(categorySlug('☕'), '');
    final now = DateTime.utc(2026);
    final food = Category(
      id: 'f',
      name: 'Food',
      slug: 'food',
      kind: CategoryKind.outcome,
      color: MelaIdentity.slate.toARGB32(),
      icon: 'utensils',
      isSystem: false,
      isArchived: false,
      sortOrder: 4,
      createdAt: now,
      updatedAt: now,
    );
    final input = newCategoryInput('Kopi', CategoryKind.outcome, [food]);
    expect(input.slug, 'kopi');
    expect(input.color, MelaIdentity.blue.toARGB32());
    expect(input.sortOrder, 5);
  });

  testWidgets('capture: an unknown #word becomes a new category', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byType(PCaptureBar).first);
    await _settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(CaptureSheet),
        matching: find.byType(EditableText),
      ),
      '-20k kopi #jajan',
    );
    await _settle(tester);

    await _tap(tester, _chip('Category', 'Uncategorized'));
    // The picker opens on the typed word and offers to add it.
    expect(find.text('jajan'), findsWidgets);
    await _tap(tester, find.byKey(const ValueKey('category-create')));
    expect(_chip('Category', 'jajan'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    final jajan = (await _categories(tester))
        .singleWhere((c) => c.slug == 'jajan');
    expect(jajan.kind, CategoryKind.outcome);
    final work = _container(tester)
        .read(transactionRepositoryProvider)
        .watchRange(const LocalDate(2000, 1, 1), const LocalDate(2100, 1, 1))
        .first;
    late List<dynamic> txns;
    await tester.runAsync(() async => txns = await work);
    expect(txns.single.categoryId, jajan.id);
    await tester.pump(const Duration(seconds: 6));
    await _settle(tester);
  });

  testWidgets('finance: add, edit and archive a category', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('tab-finance')));
    await _settle(tester);

    await _scrollTo(tester, _button(FinanceStrings.addCategory));
    await _tap(tester, _button(FinanceStrings.addCategory));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey(FinanceStrings.name)),
        matching: find.byType(EditableText),
      ),
      'Pets',
    );
    await _settle(tester);
    await _tap(tester, find.byKey(const ValueKey('icon-paw-print')));
    await _tap(tester, _chip(null, 'Violet'));
    await _tap(tester, _button(MelaStrings.save));

    var pets = (await _categories(tester)).singleWhere((c) => c.slug == 'pets');
    expect(pets.icon, 'paw-print');
    expect(pets.color, MelaIdentity.violet.toARGB32());
    final chip = _chip(FinanceStrings.spendingCategories, 'Pets');
    await _scrollTo(tester, chip, up: true);
    expect(chip, findsOneWidget);

    // Same name again: the handle is taken.
    await _scrollTo(tester, _button(FinanceStrings.addCategory));
    await _tap(tester, _button(FinanceStrings.addCategory));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey(FinanceStrings.name)),
        matching: find.byType(EditableText),
      ),
      'Pets',
    );
    await _settle(tester);
    await _tap(tester, _button(MelaStrings.save));
    expect(find.text(MelaStrings.categoryTaken('pets')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);

    await _scrollTo(tester, chip, up: true);
    await _tap(tester, chip);
    await _tap(tester, _button(FinanceStrings.archive));
    await _tap(tester, _button(FinanceStrings.confirmArchive));
    pets = (await _categories(tester)).singleWhere((c) => c.slug == 'pets');
    expect(pets.isArchived, isTrue);
    expect(chip, findsNothing);
  });
}
