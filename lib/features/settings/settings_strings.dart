/// Settings and reminder words, in one place until the app has localisation.
abstract final class SettingsStrings {
  static const appearance = 'Appearance';
  static const about = 'About';

  /// Keep equal to pubspec.yaml; test/tool/update_safety_test.dart checks.
  static const version = 'Version 1.1';
  static const themeSystem = 'System';
  static const themeLight = 'Light';
  static const themeDark = 'Dark';
  static const theme = 'Theme';

  static const reminders = 'Reminders';
  static const dueTime = 'Due date reminder time';
  static const dueTimeHint =
      'Tasks with a due date and no set time remind you then.';

  static const backup = 'Backup';
  static const backupHint =
      'A copy of all your data as one SQLite file. It is not encrypted.';
  static const shareBackup = 'Share backup';
  static const saveBackup = 'Save backup';
  static const backupSaved = 'Backup saved';
  static const jsonSaved = 'JSON copy saved';
  static const jsonFailed = 'Couldn’t export the JSON copy. Try again.';
  static const backupFailed = 'Couldn’t export the backup. Try again.';
  static const saveFailed = 'Couldn’t save the setting. Try again.';

  static const jsonHint =
      'A readable JSON copy for other tools. It can’t be restored, and it is '
      'not encrypted.';
  static const shareJson = 'Share JSON';
  static const saveJson = 'Save JSON';

  static const restore = 'Restore';
  static const restoreHint =
      'Replace everything in MelaTime with a SQLite backup.';
  static const chooseBackup = 'Choose file';
  static const restoreTitle = 'Restore this backup?';
  static const restoreWarning =
      'Everything in MelaTime now will be replaced. A copy of the current data is '
      'kept on this device until the next restore.';
  static const restoreConfirm = 'Replace data';
  static const cancel = 'Cancel';
  static const restoring = 'Restoring…';
  static const restored = 'Backup restored';
  static const restoreFailed =
      'Couldn’t restore, so your data is unchanged. Try again.';
  static const readFailed = 'Couldn’t read that file. Choose another.';
  static const refusedNotPulse =
      'That isn’t a MelaTime backup. Choose another file.';
  static const refusedNewer =
      'That backup was made by a newer version of MelaTime. Update the app, then '
      'restore it.';
  static const refusedDamaged =
      'That backup is damaged or incomplete. Choose another file.';
  static const refusedSchema =
      'That file was changed outside MelaTime. Choose another file.';
  static const unknownDate = 'Export date unknown';
  static String exportedOn(String date) => 'Exported $date';
  static String rows(int count) => count == 1 ? '1 row' : '$count rows';

  static const tableNames = {
    'wallets': 'Wallets',
    'categories': 'Categories',
    'transactions': 'Transactions',
    'budgets': 'Budgets',
    'recurring_rules': 'Recurring rules',
    'recurring_occurrences': 'Recurring entries',
    'action_items': 'Tasks and events',
    'notes': 'Notes',
    'tags': 'Tags',
    'taggings': 'Tag links',
    'app_settings': 'Settings',
  };

  // Notifications.
  static const channelName = 'Reminders';
  static const channelDescription = 'Tasks, events and recurring entries';
  static const dueToday = 'Due today';
  static const recurringDue = 'Recurring entry due today';
  static String startsAt(String time) => 'Starts at $time';
}
