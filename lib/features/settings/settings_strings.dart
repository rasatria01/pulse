/// Settings and reminder words, in one place until the app has localisation.
abstract final class SettingsStrings {
  static const appearance = 'Appearance';
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
  static const saveBackup = 'Save to device';
  static const backupSaved = 'Backup saved';
  static const backupFailed = 'Could not export the backup';
  static const saveFailed = 'Could not save the setting';

  static const jsonHint =
      'A readable JSON copy for other tools. It can\'t be restored, and it is '
      'not encrypted.';
  static const shareJson = 'Share JSON';
  static const saveJson = 'Save JSON';

  static const restore = 'Restore';
  static const restoreHint =
      'Replace everything in Pulse with a SQLite backup.';
  static const chooseBackup = 'Choose backup file';
  static const restoreTitle = 'Restore this backup?';
  static const restoreWarning =
      'Everything in Pulse now will be replaced. A copy of the current data is '
      'kept on this device until the next restore.';
  static const restoreConfirm = 'Replace my data';
  static const cancel = 'Cancel';
  static const restoring = 'Restoring…';
  static const restored = 'Backup restored';
  static const restoreFailed =
      'Could not restore the backup. Your data is unchanged.';
  static const readFailed = 'Could not read that file';
  static const refusedNotPulse = 'That file is not a Pulse backup.';
  static const refusedNewer =
      'That backup was made by a newer version of Pulse. Update the app, then '
      'restore it.';
  static const refusedDamaged = 'That backup is damaged or incomplete.';
  static const refusedSchema =
      'That file has been changed outside Pulse, so it was refused.';
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
