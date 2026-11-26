// The turmeric "now" mark moves with the clock on an open screen.
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
  testWidgets('the "now" mark moves on when an item is over', (tester) async {
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
        child: const MelaApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MelaApp)),
    );
    for (final (title, minutes) in [('Standup', 2), ('Review', 60)]) {
      container
          .read(actionItemRepositoryProvider)
          .create(
            ActionItemInput(
              title: title,
              scheduledStart: clock.nowUtc().add(Duration(minutes: minutes)),
            ),
          )
          .ignore();
    }
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    List<bool> now() => [
      for (final row in tester.widgetList<PTimelineItem>(
        find.byType(PTimelineItem),
      ))
        row.now,
    ];
    expect(now(), [true, false]);

    // Standup has no end, so it is over 30 minutes after it started.
    clock.passed = const Duration(minutes: 32);
    await tester.pump(const Duration(minutes: 32));
    await tester.pumpAndSettle();
    expect(now(), [false, true]);
  });
}
