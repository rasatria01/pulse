// Providers owned by the reminders + backup + settings thread (G). Exported by
// di.dart.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform/alarm_platform.dart';
import '../data/platform/file_backup_gateway.dart';
import '../data/platform/local_notifications_scheduler.dart';
import '../data/platform/noop_reminder_scheduler.dart';
import '../domain/services/backup_gateway.dart';
import '../domain/services/reminder_scheduler.dart';
import '../features/settings/settings_strings.dart';
import 'di.dart';

/// Off Android (tests on the host) there are no alarms to set.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => !Platform.isAndroid
      ? const NoopReminderScheduler()
      : LocalNotificationsScheduler(
          platform: AndroidAlarmPlatform(
            channelName: SettingsStrings.channelName,
            channelDescription: SettingsStrings.channelDescription,
          ),
          items: ref.watch(actionItemRepositoryProvider),
          rules: ref.watch(recurringRepositoryProvider),
          settings: ref.watch(settingsRepositoryProvider),
          unitOfWork: ref.watch(unitOfWorkProvider),
          clock: ref.watch(clockProvider),
          copy: (
            startsAt: SettingsStrings.startsAt,
            dueToday: SettingsStrings.dueToday,
            recurringDue: SettingsStrings.recurringDue,
          ),
        ),
);

final backupGatewayProvider = Provider<BackupGateway>(
  (ref) => FileBackupGateway(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);
