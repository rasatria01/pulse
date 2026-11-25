import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/app.dart';
import 'package:pulse/ui/tokens.dart';
import 'package:shad/shad.dart';

void main() {
  for (final (mode, colors) in [
    (ShadThemeMode.light, PulseColors.light),
    (ShadThemeMode.dark, PulseColors.dark),
  ]) {
    testWidgets('boots to Today at 1.3x text, ${mode.name}', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(PulseApp(themeMode: mode));
      await tester.pumpAndSettle();

      final title = find.text('Today');
      expect(title, findsOneWidget);
      expect(
        ShadTheme.of(tester.element(title)).colorScheme.background,
        colors.bg,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
