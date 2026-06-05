abstract interface class LocalDatabaseService {
  Future<void> open();

  Future<void> close();

  Future<void> runMigration();

  Future<T> transaction<T>(Future<T> Function() action);
}
