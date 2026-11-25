import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// pulse.sqlite in the app documents directory; restore replaces this file.
Future<File> databaseFile() async =>
    File('${(await getApplicationDocumentsDirectory()).path}/pulse.sqlite');

/// Queried on a background isolate.
QueryExecutor openConnection() => driftDatabase(
  name: 'pulse',
  native: DriftNativeOptions(
    databasePath: () async => (await databaseFile()).path,
  ),
);
