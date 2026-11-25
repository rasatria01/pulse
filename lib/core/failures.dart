/// The only errors that cross a layer boundary.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.field});
  final String? field;
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// A unique index was hit.
final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message);
}

final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, [this.cause]);
  final Object? cause;
}
