// The part of a restore that bootstrap's start path can't do for itself.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../features/settings/settings_strings.dart';
import 'di.dart';

/// Takes the app off screen, disposes the old scope and restores [path] over
/// [db]. Returns whether the data was replaced; either way the caller must
/// start the app again.
Future<bool> restoreAndStop(
  ProviderContainer container,
  AppDatabase db,
  String path, {
  required VoidCallback stop,
}) async {
  final gateway = container.read(backupGatewayProvider);
  // Unmounted first, so that no screen reads or writes a closing database.
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF000000),
        child: Center(
          child: Text(
            SettingsStrings.restoring,
            style: TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  stop();
  // Before the database closes: drift's close waits for its streams, and a
  // provider nothing watches holds its stream paused, which never ends.
  container.dispose();

  var replaced = false;
  try {
    await gateway.restore(path);
    replaced = true;
  } catch (e) {
    // The type only: a message may carry file content.
    debugPrint('restore failed: ${e.runtimeType}');
  }
  try {
    await gateway.discard(path);
  } catch (_) {
    // A leftover cache file must not stop the restart.
  }
  await db.close(); // a no-op if the restore got that far
  return replaced;
}
