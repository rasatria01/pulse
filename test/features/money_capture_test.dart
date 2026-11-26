import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/platform/uuid_id_generator.dart';
import 'package:pulse/data/repositories/drift_transaction_repository.dart';
import 'package:pulse/data/repositories/drift_wallet_repository.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/entities/wallet.dart';
import 'package:pulse/domain/repositories/settings_repository.dart';
import 'package:pulse/features/capture/capture_sheet.dart';
import 'package:pulse/features/finance/transaction_sheet.dart';
import 'package:pulse/features/finance/wallet_sheet.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

import '../data/support.dart';
import 'support.dart';

const _clock = FixedClock();
const _ids = UuidIdGenerator();

DriftWalletRepository _wallets(AppDatabase db) =>
    DriftWalletRepository(db, _clock, _ids);

DriftTransactionRepository _transactions(AppDatabase db) =>
    DriftTransactionRepository(db, _clock, _ids);

Future<Wallet> _addGoPay(AppDatabase db) => _wallets(db).create(
  const WalletInput(
    name: 'GoPay',
    slug: 'gopay',
    kind: WalletKind.ewallet,
    color: 0xFF14958A,
    icon: 'smartphone',
    initialBalance: Rupiah(100000),
  ),
);

Future<List<Transaction>> _history(AppDatabase db) =>
    _transactions(db).watchDay(today).first;

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 740);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// pumpAndSettle that also turns the real event loop: a drift `stream.first`
/// finishes its cancel there, outside the test's fake async.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

Future<void> _openCapture(WidgetTester tester) async {
  await tester.tap(find.byType(PCaptureBar).first);
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(CaptureSheet),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _settle(tester);
}

/// Swipe-down stand-in: a tap on the scrim.
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await _settle(tester);
}

/// Lets the 5 s snackbar timers run out.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await _settle(tester);
}

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is PButton && (w.semanticLabel ?? w.label) == label,
);

Finder _chip(String? field, String label) => find.byWidgetPredicate(
  (w) => w is PChip && w.field == field && w.label == label,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

List<String> _chipFields(WidgetTester tester) => [
  for (final chip in tester.widgetList<PChip>(
    find.descendant(
      of: find.byType(CaptureSheet),
      matching: find.byType(PChip),
    ),
  ))
    chip.field!,
];

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<PButton>(_button(MelaStrings.save)).onPressed != null;

const _minus = '−';
const _space = ' ';

void main() {
  testWidgets('M1: "-35k lunch @gopay #food" saves and shows on Today', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    final gopay = await _addGoPay(db);
    await _settle(tester);

    await _openCapture(tester);
    await _type(tester, '-35k lunch @gopay #food');
    expect(_chipFields(tester), [
      'Kind',
      'Amount',
      'Wallet',
      'Category',
      'Date',
      'Tags',
    ]);
    await _enter(tester);

    // Saved, the field cleared, the sheet still open with Undo.
    expect(find.byType(CaptureSheet), findsOneWidget);
    expect(find.text('Saved “lunch” to GoPay'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '',
    );
    final saved = (await _history(db)).single;
    expect(saved.amount, const Rupiah(35000));
    expect(saved.walletId, gopay.id);
    expect(saved.type, TxnType.outcome);
    expect(saved.categoryId, isNotNull);

    await _closeSheet(tester);
    expect(find.byType(CaptureSheet), findsNothing);
    // Balance 100.000 - 35.000, and today's spend.
    expect(find.text('Rp${_space}65.000'), findsWidgets);
    expect(find.text('Rp${_space}35.000'), findsOneWidget);
    expect(find.text(MelaStrings.setBudget), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('Undo removes the entry; the window closes after 5 s', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await _openCapture(tester);
    await _type(tester, '-20k coffee');
    await _enter(tester);
    expect(await _history(db), hasLength(1));
    await _tap(tester, _button(MelaStrings.undo));
    expect(await _history(db), isEmpty);
    expect(find.byType(PSnackbar), findsNothing);

    await _type(tester, '-20k tea');
    await _enter(tester);
    expect(find.byType(PSnackbar), findsOneWidget);
    await _drain(tester);
    expect(find.byType(PSnackbar), findsNothing);
    expect(await _history(db), hasLength(1));
  });

  testWidgets('closing the sheet inside the window keeps Undo reachable', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await _openCapture(tester);
    await _type(tester, '-20k coffee');
    await _enter(tester);
    await _closeSheet(tester);
    await _tap(tester, _button(MelaStrings.undo));
    expect(await _history(db), isEmpty);
    await _drain(tester);
  });

  testWidgets('unsaved text is stored and comes back', (tester) async {
    final db = await pumpApp(tester);
    // Not a stream: `.first` would hang in the test's fake async.
    Future<String?> stored() async =>
        (await db
                .customSelect(
                  "SELECT value FROM app_settings WHERE key = "
                  "'${SettingKeys.captureDraft}'",
                )
                .getSingleOrNull())
            ?.read<String>('value');
    await _openCapture(tester);
    await _type(tester, 'call the bank');
    expect(await stored(), 'call the bank');
    await _closeSheet(tester);

    await _openCapture(tester);
    expect(find.text('call the bank'), findsOneWidget);
    await _enter(tester);
    expect(await stored(), '');
    await _drain(tester);
  });

  testWidgets('a picked wallet fixes the error and wins over the text', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    final gopay = await _addGoPay(db);
    await _settle(tester);
    await _openCapture(tester);
    await _type(tester, '-35k lunch @gopy');
    expect(_chip('Wallet', '@gopy'), findsOneWidget);
    expect(
      tester.widget<PChip>(_chip('Wallet', '@gopy')).tone,
      PChipTone.error,
    );
    expect(_saveEnabled(tester), isFalse);
    expect(find.textContaining('isn’t a wallet'), findsOneWidget);
    await _enter(tester);
    expect(await _history(db), isEmpty);

    await _tap(tester, _chip('Wallet', '@gopy'));
    await _tap(tester, _chip(null, 'GoPay'));
    expect(_chip('Wallet', 'GoPay'), findsOneWidget);
    // Further typing does not undo the pick.
    await _type(tester, '-35k lunch @gopy again');
    expect(_chip('Wallet', 'GoPay'), findsOneWidget);
    await _enter(tester);
    expect((await _history(db)).single.walletId, gopay.id);
    await _drain(tester);
  });

  testWidgets('kind, amount and date pickers override the parse', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await _openCapture(tester);
    await _type(tester, 'lunch');
    expect(_chipFields(tester), ['Kind', 'Date', 'Priority', 'Tags']);

    await _tap(tester, _chip('Kind', 'Task'));
    await _tap(tester, _chip(null, 'Transaction'));
    expect(_saveEnabled(tester), isFalse);

    await _tap(tester, _chip('Amount', 'Add amount'));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('amount-field')),
        matching: find.byType(EditableText),
      ),
      '12k',
    );
    await _enter(tester);
    expect(_chip('Amount', '${_minus}Rp${_space}12.000'), findsOneWidget);

    await _tap(tester, _chip('Date', 'Now'));
    expect(tester.takeException(), isNull);
    await _tap(tester, _button(MelaStrings.save).last);
    expect(_chip('Date', 'Today 10:00'), findsOneWidget);
    await _enter(tester);
    expect((await _history(db)).single.amount, const Rupiah(12000));
    await _drain(tester);
  });

  for (final mode in [ShadThemeMode.light, ShadThemeMode.dark]) {
    testWidgets('money screens fit a phone at 1.3x text, ${mode.name}', (
      tester,
    ) async {
      _phone(tester);
      final db = await pumpApp(tester, mode: mode);
      await _addGoPay(db);
      await _settle(tester);

      await _openCapture(tester);
      for (final text in [
        '-35k lunch at the very long named place @gopay #food #team',
        '500k @cash>@nope topup',
        'Pay rent 2.500.000 besok !high @gopay #bill #home',
        'note: an idea #later',
        '-35k lunch @gopay',
      ]) {
        await _type(tester, text);
        expect(tester.takeException(), isNull, reason: text);
      }
      await _enter(tester);
      expect(tester.takeException(), isNull);
      await _closeSheet(tester);
      await _drain(tester);

      await tester.tap(find.byKey(const ValueKey('tab-finance')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('wallet-gopay')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Edit the expense, then delete it and undo. The list is lazy.
      await tester.scrollUntilVisible(
        find.text('lunch'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _tap(tester, find.text('lunch'));
      expect(find.byType(TransactionSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, _chip('Category', 'Uncategorized'));
      await _tap(tester, _chip(null, 'Food'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('Amount')),
          matching: find.byType(EditableText),
        ),
        '40000',
      );
      await _tap(tester, _button(MelaStrings.save));
      final edited = (await _history(db)).single;
      expect(edited.amount, const Rupiah(40000));
      expect(edited.occurredOn, today);

      await _tap(tester, find.text('lunch'));
      await _tap(tester, _button('Delete'));
      await _tap(tester, _button('Confirm delete'));
      expect(await _history(db), isEmpty);
      await _tap(tester, _button(MelaStrings.undo));
      expect(await _history(db), hasLength(1));
      await _drain(tester);

      // Transfer GoPay -> Cash.
      await _tap(tester, _button('Transfer'));
      await _tap(tester, _chip('To wallet', 'Wallet'));
      await _tap(tester, _chip(null, 'GoPay'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('Amount')),
          matching: find.byType(EditableText),
        ),
        '10k',
      );
      await _tap(tester, _button(MelaStrings.save));
      expect(
        (await _history(db)).where((t) => t.type == TxnType.transfer),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);

      // Add a wallet; a taken handle is refused.
      await _tap(tester, _button('Add wallet'));
      expect(find.byType(WalletSheet), findsOneWidget);
      Future<void> fill(String field, String text) => tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey(field)),
          matching: find.byType(EditableText),
        ),
        text,
      );
      await fill('Name', 'GoPay');
      await _tap(tester, _button(MelaStrings.save));
      expect(
        find.text('@gopay is already used. Pick another handle.'),
        findsOneWidget,
      );
      await fill('Name', 'Savings');
      await fill('Starting balance', '-5k');
      await _tap(tester, _button(MelaStrings.save));
      expect(find.byType(WalletSheet), findsNothing);
      expect(tester.takeException(), isNull);

      // Make it the default, then archive the old default.
      await _tap(tester, find.byKey(const ValueKey('wallet-savings')));
      await _tap(tester, _button('Set default'));
      // The first wallet may sit just above the viewport.
      await _tap(
        tester,
        find.byKey(const ValueKey('wallet-cash'), skipOffstage: false),
      );
      await _tap(tester, _button('Archive'));
      await _tap(tester, _button('Confirm archive'));
      final all = await _wallets(db).watchAll(includeArchived: true).first;
      final bySlug = {for (final b in all) b.wallet.slug: b};
      expect(bySlug['savings']!.wallet.isDefault, isTrue);
      expect(bySlug['savings']!.balance, const Rupiah(-5000));
      expect(bySlug['cash']!.wallet.isArchived, isTrue);
      final cash = find.byKey(
        const ValueKey('wallet-cash'),
        skipOffstage: false,
      );
      expect(cash, findsNothing);
      await _tap(tester, _button('Show archived'));
      expect(cash, findsOneWidget);
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });
  }
}
