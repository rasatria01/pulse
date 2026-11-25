import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/calendar/calendar_screen.dart';
import 'package:pulse/features/capture/capture_sheet.dart';
import 'package:pulse/features/finance/finance_screen.dart';
import 'package:pulse/features/notes/notes_screen.dart';
import 'package:pulse/features/search/search_screen.dart';
import 'package:pulse/features/settings/settings_screen.dart';
import 'package:pulse/features/tasks/tasks_screen.dart';
import 'package:pulse/features/today/today_screen.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

import 'support.dart';

const _tabs = {
  'tasks': TasksScreen,
  'calendar': CalendarScreen,
  'notes': NotesScreen,
  'finance': FinanceScreen,
  'today': TodayScreen,
};

void main() {
  for (final (mode, colors) in [
    (ShadThemeMode.light, PulseColors.light),
    (ShadThemeMode.dark, PulseColors.dark),
  ]) {
    testWidgets('every screen opens on a phone at 1.3x text, ${mode.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, mode: mode);

      void expectScreen(Type screen) {
        expect(find.byType(screen), findsOneWidget);
        expect(
          ShadTheme.of(tester.element(find.byType(screen)))
              .colorScheme
              .background,
          colors.bg,
        );
        expect(tester.takeException(), isNull);
      }

      expectScreen(TodayScreen);
      for (final MapEntry(key: tab, value: screen) in _tabs.entries) {
        await tester.tap(find.byKey(ValueKey('tab-$tab')));
        await tester.pumpAndSettle();
        expectScreen(screen);
        expect(find.byType(PCaptureBar), findsOneWidget);
      }

      for (final (label, screen) in [
        (PulseStrings.search, SearchScreen),
        (PulseStrings.settings, SettingsScreen),
      ]) {
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is PButton && w.semanticLabel == label,
          ),
        );
        await tester.pumpAndSettle();
        expectScreen(screen);
        expect(find.byType(PCaptureBar), findsNothing);

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is PButton && w.semanticLabel == PulseStrings.back,
          ),
        );
        await tester.pumpAndSettle();
        expectScreen(TodayScreen);
      }

      // The last Today section is reachable by scrolling.
      await tester.scrollUntilVisible(
        find.text(PulseStrings.noScratchpad),
        200,
        // The first is the list itself; sections may hold chip rows.
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(PCaptureBar));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
