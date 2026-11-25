import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Plus Jakarta Sans',
    ], await rootBundle.loadString('assets/licenses/PlusJakartaSans-OFL.txt'));
  });
  runApp(
    // No retries: a local database error will not fix itself.
    ProviderScope(retry: (_, _) => null, child: const PulseApp()),
  );
}
