import '../../domain/services/unit_of_work.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';

final class DriftUnitOfWork implements UnitOfWork {
  DriftUnitOfWork(this._db);

  final AppDatabase _db;

  // Drift tracks the transaction in a zone, so repository calls join it.
  @override
  Future<T> run<T>(Future<T> Function() body) =>
      guard(() => _db.transaction(body));
}
