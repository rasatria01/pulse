import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/ui/theme.dart';
import 'package:pulse/ui/widgets/gallery_screen.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

const _variants = [
  ('light', Brightness.light, 1.0),
  ('dark', Brightness.dark, 1.0),
  ('light 1.3x', Brightness.light, 1.3),
  ('dark 1.3x', Brightness.dark, 1.3),
];

/// A 360 dp wide phone, tall enough to lay out the whole gallery.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double scale = 1,
  bool still = false,
}) async {
  tester.view.physicalSize = const Size(360, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (still) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    ShadApp(
      theme: pulseTheme(Brightness.light),
      darkTheme: pulseTheme(Brightness.dark),
      themeMode: brightness == Brightness.light
          ? ShadThemeMode.light
          : ShadThemeMode.dark,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('amount formatting', () {
    const nbsp = '\u00a0';
    const minus = '\u2212';

    test('Rp, no-break space, dot groups and the sign by type', () {
      expect(
        formatAmount(const Rupiah(35000), AmountType.outcome),
        '${minus}Rp${nbsp}35.000',
      );
      expect(
        formatAmount(const Rupiah(7500000), AmountType.income),
        '+Rp${nbsp}7.500.000',
      );
      expect(
        formatAmount(const Rupiah(200000), AmountType.transfer),
        'Rp${nbsp}200.000',
      );
      expect(
        formatAmount(const Rupiah(4250000), AmountType.balance),
        'Rp${nbsp}4.250.000',
      );
      expect(
        formatAmount(const Rupiah(-120000), AmountType.balance),
        '${minus}Rp${nbsp}120.000',
      );
      expect(formatAmount(Rupiah.zero, AmountType.balance), 'Rp${nbsp}0');

      // By code point, so a broken escape can't match itself on both sides.
      expect(formatAmount(const Rupiah(5), AmountType.outcome).codeUnits, [
        0x2212,
        0x52,
        0x70,
        0xA0,
        0x35,
      ]);
    });

    test('screen readers get words', () {
      expect(
        amountLabel(const Rupiah(35000), AmountType.outcome),
        'Expense Rp 35.000',
      );
      expect(
        amountLabel(const Rupiah(-5), AmountType.balance),
        'Balance minus Rp 5',
      );
    });
  });

  test('stored colours and icon names resolve with fallbacks', () {
    expect(identityColor(PulseIdentity.teal.toARGB32()), PulseIdentity.teal);
    expect(identityColor(0xFF123456), PulseIdentity.slate);
    for (final name in [
      'wallet',
      'banknote',
      'landmark',
      'smartphone',
      'utensils',
      'bus',
      'receipt-text',
      'tag',
    ]) {
      expect(pulseIcons, contains(name));
    }
    expect(pulseIcon('nope'), LucideIcons.tag);
  });

  for (final (name, brightness, scale) in _variants) {
    testWidgets('every widget lays out, $name', (tester) async {
      await _pump(
        tester,
        const GalleryScreen(),
        brightness: brightness,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      for (final type in [
        PButton,
        PChip,
        AmountText,
        EmptyState,
        PIcon,
        PCaptureBar,
        PulseCard,
        PWalletPill,
        PBudgetBar,
        PTimelineItem,
        PInboxItem,
        PConfirmRow,
        PSnackbar,
      ]) {
        expect(find.byType(type), findsWidgets, reason: '$type');
      }

      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(PSheet), findsOneWidget);
      expect(find.text('Pay electricity bill'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(PSheet), findsNothing);

      await tester.tap(find.text('Show snackbar'));
      await tester.pumpAndSettle();
      expect(find.byType(PSnackbar), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(PSnackbar), findsOneWidget);
    });
  }

  testWidgets('tap targets are 48 and labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const GalleryScreen());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(find.bySemanticsLabel('Wallet: GoPay'), findsOneWidget);
    expect(find.bySemanticsLabel('Complete Pay internet'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a control fires once, from the padding or the middle', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      Center(
        child: PButton.secondary(
          label: 'Edit',
          size: PButtonSize.sm,
          onPressed: () => taps++,
        ),
      ),
    );
    final centre = tester.getCenter(find.byType(PButton));
    await tester.tapAt(centre);
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.tapAt(centre + const Offset(0, 22));
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('an error chip disables Save and shows the hint', (tester) async {
    var saves = 0;
    final controller = TextEditingController(text: 'x');
    addTearDown(controller.dispose);
    Widget bar(PChipTone tone) => Center(
      child: PCaptureBar.open(
        controller: controller,
        onSave: () => saves++,
        hint: 'Pick a wallet.',
        chips: [PChip(label: '@gopy', tone: tone)],
      ),
    );

    await _pump(tester, bar(PChipTone.error));
    // Disabled, so the tap is expected to hit nothing.
    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('Pick a wallet.'), findsOneWidget);

    await _pump(tester, bar(PChipTone.neutral));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Pick a wallet.'), findsNothing);
  });

  testWidgets('budget status is said in words', (tester) async {
    Future<void> show(int spent) => _pump(
      tester,
      Center(
        child: PBudgetBar(
          category: 'Food',
          color: 0,
          spent: Rupiah(spent),
          cap: const Rupiah(1000000),
        ),
      ),
    );

    await show(860000);
    expect(find.text('86% used'), findsOneWidget);
    await show(1000000);
    expect(find.text('100% used'), findsOneWidget);
    expect(find.text('Cap reached'), findsOneWidget);
    await show(1112000);
    expect(find.text('Over by Rp\u00a0112.000'), findsOneWidget);
  });

  testWidgets('inbox: swipe and long press, with reduce motion', (
    tester,
  ) async {
    final calls = <String>[];
    await _pump(
      tester,
      Center(
        child: PInboxItem(
          title: 'Pay internet',
          reason: InboxReason.today,
          onComplete: (v) => calls.add('complete $v'),
          onSchedule: () => calls.add('schedule'),
        ),
      ),
      still: true,
    );
    await tester.drag(find.text('Pay internet'), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Pay internet'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Pay internet'));
    await tester.pumpAndSettle();
    expect(calls, ['complete true', 'schedule', 'schedule']);
    expect(tester.takeException(), isNull);
  });
}
