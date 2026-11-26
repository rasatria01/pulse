// The "happening now" mark moves with the clock on an open screen.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/app.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/clock.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/ui/widgets/widgets.dart';

import '../data/support.dart';

class _MovingClock implements Clock {
  var passed = Duration.zero;

  @override
  DateTime nowUtc() => const FixedClock().nowUtc().add(passed);

  @override
  DateTime nowLocal() => const FixedClock().nowLocal().add(passed);

  @override
  LocalDate today() => const FixedClock().today();
}

void main() {
  testWidgets('a row becomes "now" when its start minute arrives', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final clock = _MovingClock();
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
      clock: const FixedClock(),
    );
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
        ],
        child: const PulseApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PulseApp)),
    );
    // Starts two minutes from now.
    container
        .read(actionItemRepositoryProvider)
        .create(
          ActionItemInput(
            title: 'Standup',
            scheduledStart: clock.nowUtc().add(const Duration(minutes: 2)),
          ),
        )
        .ignore();
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    bool now() => tester.widget<PTimelineItem>(find.byType(PTimelineItem)).now;
    expect(now(), isFalse);

    clock.passed = const Duration(minutes: 2);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(now(), isTrue);
  });
}
