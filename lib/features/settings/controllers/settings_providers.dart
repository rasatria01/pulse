import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../../app/di.dart';
import '../../../domain/repositories/settings_repository.dart';

/// The stored theme choice; drives the app's themeMode.
final themeModeProvider = StreamProvider<ShadThemeMode>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.theme)
      .map(
        (value) =>
            ShadThemeMode.values.asNameMap()[value] ?? ShadThemeMode.system,
      ),
);

/// 'HH:mm' local time for due-date reminders.
final dueReminderTimeProvider = StreamProvider<String>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.dueReminderTime)
      .map((value) => value ?? '08:00'),
);
