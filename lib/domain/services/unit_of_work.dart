abstract interface class UnitOfWork {
  /// Runs [body] in one SQLite transaction; repository calls inside it join it.
  Future<T> run<T>(Future<T> Function() body);
}
