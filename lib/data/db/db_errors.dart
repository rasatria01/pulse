import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
// The only way to see what the database isolate threw.
// ignore: experimental_member_use
import 'package:drift/remote.dart';

import '../../core/failures.dart';

const _primaryKeyViolation = 1555;
const _uniqueViolation = 2067;
const _constraint = 19;

/// The AppFailure for a storage error, or null if [error] is not one.
AppFailure? toFailure(Object error) => switch (error) {
  AppFailure() => error,
  // The database runs on a background isolate, which wraps what it throws.
  DriftRemoteException() =>
    toFailure(error.remoteCause) ??
        StorageFailure('database error', error.remoteCause),
  DriftWrappedException() =>
    toFailure(error.cause ?? '') ?? StorageFailure(error.message, error.cause),
  CouldNotRollBackException() => StorageFailure('rollback failed', error),
  InvalidDataException() => ValidationFailure(error.message),
  SqliteException(
    extendedResultCode: _uniqueViolation || _primaryKeyViolation,
  ) =>
    ConflictFailure(error.message),
  SqliteException(resultCode: _constraint) => ValidationFailure(error.message),
  SqliteException() => StorageFailure(error.message, error),
  _ => null,
};

/// Runs [body], letting nothing from drift or SQLite escape.
Future<T> guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (e, s) {
    final failure = toFailure(e);
    if (failure == null) rethrow;
    Error.throwWithStackTrace(failure, s);
  }
}

extension GuardedStream<T> on Stream<T> {
  Stream<T> guarded() => handleError(
    (Object e, StackTrace s) => Error.throwWithStackTrace(toFailure(e) ?? e, s),
  );
}
