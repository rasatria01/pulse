import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../domain/services/backup_gateway.dart';
import '../db/app_database.dart';
import '../db/connection.dart';
import '../db/db_errors.dart';
import '../repositories/drift_search_repository.dart';
import 'backup_check.dart';

/// PRD 9.5. [share] and [saveAs] take a file from an export and delete it.
/// Sharing still leaves share_plus's own copy in cache/share_plus until the
/// next share.
final class FileBackupGateway implements BackupGateway {
  FileBackupGateway(
    this._db,
    this._clock, {
    this._tempDir = getTemporaryDirectory,
    this._databaseFile = databaseFile,
    this._open = NativeDatabase.createInBackground,
  });

  /// The copy of the replaced database, beside it. Only the latest is kept.
  static const preRestoreName = 'pulse-pre-restore.sqlite';

  final AppDatabase _db;
  final Clock _clock;
  final Future<Directory> Function() _tempDir;
  final Future<File> Function() _databaseFile;
  final QueryExecutor Function(File file) _open;

  @override
  Future<String> exportSqlite() => guard(() async {
    final path = await _exportPath('pulse-backup', 'sqlite');
    // VACUUM INTO refuses an existing file: a second export in the same minute.
    await _delete(path);
    // A consistent snapshot under WAL, run on the database isolate.
    await _db.customStatement('VACUUM INTO ?', [path]);
    try {
      await _finishCopy(path, _clock.nowUtc().millisecondsSinceEpoch);
    } catch (_) {
      // It may still hold what was deleted.
      await _delete(path);
      rethrow;
    }
    return path;
  });

  /// One UTF-8 JSON file: "manifest", then one array per table with the raw
  /// column values of its non-deleted rows.
  @override
  Future<String> exportJson() => guard(() async {
    final tables = <String, List<Map<String, Object?>>>{};
    // One transaction, so that the arrays agree with each other.
    await _db.transaction(() async {
      for (final table in _db.allTables) {
        if (table is VirtualTableInfo) continue; // the search index is derived
        final live = table.columnsByName.containsKey('is_deleted')
            ? ' WHERE is_deleted = 0'
            : '';
        final rows = await _db
            .customSelect('SELECT * FROM ${table.actualTableName}$live')
            .get();
        tables[table.actualTableName] = [for (final row in rows) row.data];
      }
    });
    final path = await _exportPath('pulse-export', 'json');
    await File(path).writeAsString(
      jsonEncode({
        'manifest': {
          'app_id': AppDatabase.applicationId,
          'schema_version': _db.schemaVersion,
          'exported_at': _clock.nowUtc().toIso8601String(),
          'row_counts': {
            for (final MapEntry(:key, :value) in tables.entries)
              key: value.length,
          },
        },
        ...tables,
      }),
      flush: true,
    );
    return path;
  });

  @override
  Future<void> share(String path) async {
    try {
      // share_plus hands the receiver its own copy, which it keeps in
      // cache/share_plus until the next share.
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } finally {
      await _delete(path);
    }
  }

  @override
  Future<bool> saveAs(String path) async {
    try {
      final saved = await FilePicker.saveFile(
        fileName: path.split(RegExp(r'[/\\]')).last,
        bytes: await File(path).readAsBytes(),
      );
      return saved != null;
    } finally {
      await _delete(path);
    }
  }

  @override
  Future<String?> pickBackup() async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    // Our own name: the picked one is not trusted as a path.
    final copy = File('${(await _tempDir()).path}/pulse-restore.sqlite');
    try {
      await picked.readAsByteStream().cast<List<int>>().pipe(copy.openWrite());
    } finally {
      await FilePicker.clearTemporaryFiles();
    }
    return copy.path;
  }

  @override
  Future<void> discard(String path) => _delete(path);

  @override
  Future<RestoreCheck> inspect(String path) => guard(() async {
    final reference = AppDatabase(NativeDatabase.memory());
    final Set<String> schema;
    try {
      schema = {
        for (final row in await reference.customSelect(schemaQuery).get())
          schemaEntry(
            row.data['type'],
            row.data['name'],
            row.data['tbl_name'],
            row.data['sql'],
          ),
      };
    } finally {
      await reference.close();
    }
    return checkBackup(path, schema: schema, currentVersion: _db.schemaVersion);
  });

  /// Replaces the database with the file at [path], migrated and reindexed.
  /// Closes the database this gateway was built on: the caller starts the app
  /// again, also after a failure. A failure leaves the current data in place.
  /// Throws [ValidationFailure] with a [RestoreRefusal] for a refused file.
  @override
  Future<void> restore(String path) => guard(() async {
    final live = await _databaseFile();
    final staged = File('${live.path}.restore');
    final keep = File('${live.parent.path}/$preRestoreName');
    try {
      await _delete(staged.path);
      await File(path).copy(staged.path);
      // The bytes that go in are the bytes that are checked.
      final refusal = (await inspect(staged.path)).refusal;
      if (refusal != null) throw ValidationFailure(refusal);

      // Everything into the main file, so that a plain copy of it is whole.
      final checkpoint = await _db
          .customSelect('PRAGMA wal_checkpoint(TRUNCATE)')
          .getSingle();
      if (checkpoint.data['busy'] != 0) {
        throw const StorageFailure('database is busy');
      }
      await _db.close();

      // Copy, then rename: a kill at any point leaves a whole database.
      await live.copy('${keep.path}.tmp');
      await File('${keep.path}.tmp').rename(keep.path);
      await _replace(live, staged);

      try {
        // Opening migrates an older backup.
        final restored = AppDatabase(_open(live));
        try {
          await DriftSearchRepository(restored).rebuildIndex();
        } finally {
          await restored.close();
        }
      } catch (_) {
        await keep.copy(staged.path);
        await _replace(live, staged);
        rethrow;
      }
    } finally {
      await _delete(staged.path);
    }
  });

  /// The old write-ahead log must not be replayed into the new file.
  Future<void> _replace(File live, File replacement) async {
    await _delete('${live.path}-wal');
    await _delete('${live.path}-shm');
    await replacement.rename(live.path);
  }

  Future<String> _exportPath(String prefix, String extension) async {
    final now = _clock.nowLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${(await _tempDir()).path}/$prefix-'
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.$extension';
  }

  Future<void> _delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

/// Takes the text of deleted rows out of the exported copy at [path], keeping
/// the rows and their ids, and stamps it with the export instant [now].
// Top level, so that the isolate's closure holds nothing but these two.
Future<void> _finishCopy(String path, int now) => Isolate.run(() {
  final copy = sqlite3.open(path);
  try {
    // Freed space is zeroed, not left readable.
    copy.execute('PRAGMA secure_delete = ON');
    copy.execute('BEGIN');
    for (final (table, blank) in const [
      ('notes', "title = '', body = ''"),
      ('transactions', "description = '', raw_input = NULL"),
      // An item's title cannot be empty.
      ('action_items', "title = '-', body = '', raw_input = NULL"),
      ('recurring_rules', "name = '', description = ''"),
      ('wallets', "name = '', slug = '', aliases = ''"),
      ('categories', "name = '', slug = '', aliases = ''"),
      ('tags', "name = '', slug = ''"),
    ]) {
      copy.execute('UPDATE $table SET $blank WHERE is_deleted = 1');
    }
    // The restore summary shows when the file was made; only the copy says so.
    copy.execute(
      'INSERT OR REPLACE INTO app_settings (key, value, updated_at) '
      'VALUES (?, ?, ?)',
      [exportedAtKey, '$now', now],
    );
    copy.execute('COMMIT');
    // The search index keeps the words of removed entries until rewritten.
    copy.execute("INSERT INTO search_index(search_index) VALUES ('rebuild')");
    copy.execute('VACUUM');
  } finally {
    copy.close();
  }
});
