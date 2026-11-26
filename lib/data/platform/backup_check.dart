// Validation of a picked backup (PRD 9.5). The file is untrusted: it is opened
// read-only, and nothing in its schema runs before the schema is known.
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/services/backup_gateway.dart';
import '../db/app_database.dart';

/// app_settings key holding the export instant, written into the snapshot.
const exportedAtKey = 'exported_at';

const schemaQuery = 'SELECT type, name, tbl_name, sql FROM sqlite_schema';

const _notADatabase = 26;
const _int32 = '-2147483648 AND 2147483647';
// Only what SQLite's tokenizer takes as space: to it, U+00A0 and its like are
// parts of a name.
final _space = RegExp(r'[ \t\n\r\f]+');
final _endSpace = RegExp(r'^ | $');

/// One schema object as a comparable line.
String schemaEntry(Object? type, Object? name, Object? table, Object? sql) {
  // Not trim(), which also takes Unicode spaces.
  final text = '${sql ?? ''}'.replaceAll(_space, ' ').replaceAll(_endSpace, '');
  return '$type|$name|$table|$text';
}

/// Checks the file at [path] against [schema], the entries of a database this
/// build creates. On its own isolate: integrity_check reads every page.
// ponytail: one expected schema, as there is only version 1. Version 2 must
// keep version 1's entries so that an older backup is still accepted.
Future<RestoreCheck> checkBackup(
  String path, {
  required Set<String> schema,
  required int currentVersion,
}) => Isolate.run(() => _check(path, schema, currentVersion));

RestoreCheck _check(String path, Set<String> schema, int currentVersion) {
  const damaged = RestoreCheck(refusal: RestoreRefusal.damaged);
  Database? db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    db.execute('PRAGMA trusted_schema = OFF');
    db.execute('PRAGMA cell_size_check = ON');
    Object? value(String sql) => db!.select(sql).first.values.first;

    if (value('PRAGMA application_id') != AppDatabase.applicationId) {
      return const RestoreCheck(refusal: RestoreRefusal.notPulse);
    }
    final version = value('PRAGMA user_version') as int;
    if (version > currentVersion) {
      return RestoreCheck(
        refusal: RestoreRefusal.newer,
        schemaVersion: version,
      );
    }
    if (version < 1) return damaged;

    // Exactly our objects: an added trigger or view would run with the app's
    // writes, and a missing table would break them.
    final found = {
      for (final row in db.select(schemaQuery))
        schemaEntry(row['type'], row['name'], row['tbl_name'], row['sql']),
    };
    if (found.length != schema.length || !found.containsAll(schema)) {
      return const RestoreCheck(refusal: RestoreRefusal.schema);
    }

    final integrity = db.select('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.first.values.first != 'ok') {
      return damaged;
    }
    if (db.select('PRAGMA foreign_key_check').isNotEmpty) return damaged;

    // Tables are not STRICT, so a column can hold any type; a wrong one would
    // crash every read of the row.
    final counts = <String, int>{};
    final tables = db.select(
      "SELECT name FROM pragma_table_list WHERE schema = 'main' "
      "AND type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final row in tables) {
      final table = row['name'] as String;
      var live = '';
      final bad = <String>[];
      for (final column in db.select('PRAGMA table_info("$table")')) {
        final name = column['name'] as String;
        final type = (column['type'] as String).toLowerCase();
        if (name == 'is_deleted') live = ' WHERE is_deleted = 0';
        bad.add('typeof("$name") NOT IN (\'$type\', \'null\')');
        // The two calendar formats of PRD 6, and only days that exist: date()
        // gives back anything else changed, or null.
        if (name.endsWith('_date') || name.endsWith('_on')) {
          bad.add('"$name" IS NOT date("$name")');
        }
        if (name == 'effective_from') {
          bad.add('"$name" || \'-01\' IS NOT date("$name" || \'-01\')');
        }
        // Android alarm ids are int32.
        if (name == 'notif_id') bad.add('"$name" NOT BETWEEN $_int32');
      }
      if (table == 'app_settings') {
        bad.add(
          '"key" = \'next_notif_id\' AND '
          '(value IS NOT CAST(CAST(value AS INTEGER) AS TEXT) '
          'OR CAST(value AS INTEGER) NOT BETWEEN $_int32)',
        );
      }
      if (value('SELECT count(*) FROM "$table" WHERE ${bad.join(' OR ')}') !=
          0) {
        return damaged;
      }
      // Every value must decode: text that is not UTF-8 throws on each read,
      // and the theme is read before the first frame.
      final statement = db.prepare('SELECT * FROM "$table"');
      try {
        final cursor = statement.selectCursor();
        while (cursor.moveNext()) {}
      } finally {
        statement.close();
      }
      counts[table] = value('SELECT count(*) FROM "$table"$live') as int;
    }

    final stamp = db.select('SELECT value FROM app_settings WHERE key = ?', [
      exportedAtKey,
    ]);
    final millis = stamp.isEmpty
        ? null
        : int.tryParse('${stamp.first.values.first}');
    return RestoreCheck(
      schemaVersion: version,
      // The range DateTime accepts.
      exportedAt: millis == null || millis.abs() > 8640000000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
      rowCounts: counts,
    );
  } on SqliteException catch (e) {
    return e.resultCode == _notADatabase
        ? const RestoreCheck(refusal: RestoreRefusal.notPulse)
        : damaged;
  } on FormatException {
    return damaged; // text that is not UTF-8
  } finally {
    db?.close();
  }
}
