import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../domain/repositories/settings_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';

final class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  @override
  Stream<String?> watch(String key) =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value)
          .guarded();

  @override
  Future<void> put(String key, String value) => guard(
    () => _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value, updatedAt: _now),
        ),
  );

  /// The row holds the id to hand out next. One statement, so it is atomic.
  @override
  Future<int> nextNotificationId() => guard(() async {
    final rows = await _db.customWriteReturning(
      'INSERT INTO app_settings (key, value, updated_at) VALUES (?, 2, ?) '
      'ON CONFLICT (key) DO UPDATE SET '
      'value = CAST(value AS INTEGER) + 1, updated_at = excluded.updated_at '
      'RETURNING CAST(value AS INTEGER) - 1 AS id',
      variables: [const Variable(SettingKeys.nextNotifId), Variable(_now)],
      updates: {_db.appSettings},
    );
    return rows.single.read<int>('id');
  });
}
