import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_gateway.freezed.dart';

/// Why a file may not be restored; the screen words each one.
abstract final class RestoreRefusal {
  static const notPulse = 'not_pulse';
  static const newer = 'newer';
  static const damaged = 'damaged';
  static const schema = 'schema'; // unexpected or missing schema objects
}

@freezed
abstract class RestoreCheck with _$RestoreCheck {
  const factory RestoreCheck({
    String? refusal, // a RestoreRefusal; null = the file may be restored
    int? schemaVersion,
    DateTime? exportedAt,
    @Default(<String, int>{}) Map<String, int> rowCounts, // per table
  }) = _RestoreCheck;
}

/// Implemented in data/platform.
abstract interface class BackupGateway {
  Future<String> exportSqlite(); // returns a temp file path
  Future<String> exportJson();
  Future<void> share(String path); // system share sheet
  Future<bool> saveAs(String path); // system save dialog; false = cancelled
  Future<String?> pickBackup(); // a cached copy; null = cancelled
  Future<void> discard(String path); // deletes a picked copy
  Future<RestoreCheck> inspect(String path);
  Future<void> restore(String path); // closes the database; restart after it
}
