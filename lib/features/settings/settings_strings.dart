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

  // Notifications.
  static const channelName = 'Reminders';
  static const channelDescription = 'Tasks, events and recurring entries';
  static const dueToday = 'Due today';
  static const recurringDue = 'Recurring entry due today';
  static String startsAt(String time) => 'Starts at $time';
}
