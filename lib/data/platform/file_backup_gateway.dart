import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/clock.dart';
import '../../domain/services/backup_gateway.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';

/// PRD 9.5. [share] and [saveAs] take a file from an export and delete it, so
/// no copy of the database stays behind in the cache.
final class FileBackupGateway implements BackupGateway {
  FileBackupGateway(
    this._db,
    this._clock, {
    this._tempDir = getTemporaryDirectory,
  });

  final AppDatabase _db;
  final Clock _clock;
  final Future<Directory> Function() _tempDir;

  @override
  Future<String> exportSqlite() => guard(() async {
    final now = _clock.nowLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final path =
        '${(await _tempDir()).path}/pulse-backup-'
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.sqlite';
    // VACUUM INTO refuses an existing file: a second export in the same minute.
    await _delete(path);
    // A consistent snapshot under WAL, run on the database isolate.
    await _db.customStatement('VACUUM INTO ?', [path]);
    return path;
  });

  @override
  Future<void> share(String path) async {
    try {
      // share_plus hands the receiver its own copy in cache/share_plus.
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

  // JSON export and restore arrive in wave 3 (milestone M5); no UI offers them.

  @override
  Future<String> exportJson() => throw UnimplementedError('wave 3');

  @override
  Future<String?> pickBackup() => throw UnimplementedError('wave 3');

  @override
  Future<RestoreCheck> inspect(String path) =>
      throw UnimplementedError('wave 3');

  @override
  Future<void> restore(String path) => throw UnimplementedError('wave 3');

  Future<void> _delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
