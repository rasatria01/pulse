import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'data/db/app_database.dart';
import 'data/db/connection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Plus Jakarta Sans',
    ], await rootBundle.loadString('assets/licenses/PlusJakartaSans-OFL.txt'));
  });
  final db = AppDatabase(openConnection());
  // Drift opens lazily; create or migrate before the first frame.
  await db.customSelect('SELECT 1').get();
  runApp(
    ProviderScope(
      // No retries: a local database error will not fix itself.
      retry: (_, _) => null,
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const PulseApp(),
    ),
  );
}
