import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// The app loads the id_ID date names before its first frame; so do tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('id_ID');
  await testMain();
}
