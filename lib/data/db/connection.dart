import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// pulse.sqlite in the app documents directory, queried on a background isolate.
QueryExecutor openConnection() => driftDatabase(name: 'pulse');
