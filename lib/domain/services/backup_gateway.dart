import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_gateway.freezed.dart';

@freezed
abstract class RestoreCheck with _$RestoreCheck {
  const factory RestoreCheck({
    String? refusal, // null = the file may be restored
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
  Future<String?> pickBackup(); // system file picker; null = cancelled
  Future<RestoreCheck> inspect(String path);
  Future<void> restore(String path);
}
