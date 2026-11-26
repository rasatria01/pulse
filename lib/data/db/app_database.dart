import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../platform/uuid_id_generator.dart';

part 'app_database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(
    super.executor, {
    this.clock = const SystemClock(),
    this.ids = const UuidIdGenerator(),
  });

  /// 0x50554C53 ('PULS'), checked by restore.
  static const applicationId = 1347767379;

  final Clock clock;
  final IdGenerator ids;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // All or nothing: a half-created file would fail every later open.
      await transaction(() async {
        await m.createAll();
        await _seed();
        await customStatement('PRAGMA application_id = $applicationId');
        // Drift writes this only after beforeOpen; a kill in between would
        // rerun onCreate on a full database. Migration steps need it too.
        await customStatement('PRAGMA user_version = $schemaVersion');
      });
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
    },
  );

  /// First-run rows only; never part of a migration step.
  Future<void> _seed() async {
    final now = clock.nowUtc().millisecondsSinceEpoch;

    await into(wallets).insert(
      WalletsCompanion.insert(
        id: ids.newId(),
        name: 'Cash',
        slug: 'cash',
        kind: 'cash',
        color: 0xFF36923B, // MelaIdentity.green
        icon: 'wallet',
        isDefault: const Value(1),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Colours are MelaIdentity values: slate, orange, blue, amber, teal.
    const seeded = [
      ('Uncategorized', 'uncategorized', 'outcome', 0xFF6E7E95, 'circle-help'),
      ('Food', 'food', 'outcome', 0xFFD9622B, 'utensils'),
      ('Transport', 'transport', 'outcome', 0xFF3B74E0, 'bus'),
      ('Bills', 'bills', 'outcome', 0xFFB7791F, 'receipt'),
      ('Uncategorized', 'uncategorized', 'income', 0xFF6E7E95, 'circle-help'),
      ('Income', 'income', 'income', 0xFF14958A, 'banknote'),
    ];
    for (final (i, (name, slug, kind, color, icon)) in seeded.indexed) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: ids.newId(),
          name: name,
          slug: slug,
          kind: kind,
          color: color,
          icon: icon,
          isSystem: Value(slug == 'uncategorized' ? 1 : 0),
          sortOrder: Value(i),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
}
