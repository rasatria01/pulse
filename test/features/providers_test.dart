import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/clock.dart';
import 'package:pulse/core/local_date.dart';

final class _MovableClock implements Clock {
  DateTime now = DateTime(2026, 11, 25, 23, 59);

  @override
  DateTime nowUtc() => now.toUtc();

  @override
  DateTime nowLocal() => now;

  @override
  LocalDate today() => LocalDate.fromDateTime(now);
}

void main() {
  testWidgets('today rolls over at midnight and on resume', (tester) async {
    final clock = _MovableClock();
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    final seen = <LocalDate>[];
    container.listen(
      todayProvider,
      (_, day) => seen.add(day),
      fireImmediately: true,
    );

    clock.now = DateTime(2026, 11, 26);
    await tester.pump(const Duration(minutes: 1));
    expect(seen.last, const LocalDate(2026, 11, 26));

    // Days pass in the background, with no timer firing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    clock.now = DateTime(2026, 11, 29, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(container.read(todayProvider), const LocalDate(2026, 11, 29));
    expect(seen, hasLength(3));

    // Disposing cancels the next timer, or the test would fail on it.
    container.dispose();
  });
}
