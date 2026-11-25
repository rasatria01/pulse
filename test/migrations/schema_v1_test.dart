// make-migrations writes its step tests once there is a version 2. Until then,
// this holds the code to the frozen drift_schemas/ dump.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/db/app_database.dart';

import 'app_database/generated/schema.dart';

void main() {
  test('a new database matches the frozen schema v1', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final verifier = SchemaVerifier(GeneratedHelper());
    // Runs onCreate, then compares the result with the frozen dump.
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await verifier.migrateAndValidate(
      fresh,
      1,
      options: const ValidationOptions(validateDropped: true),
    );
  });
}
