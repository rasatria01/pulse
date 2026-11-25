/// Keys of the app_settings table.
abstract final class SettingKeys {
  static const theme = 'theme';
  static const dueReminderTime = 'due_reminder_time'; // '08:00'
  static const weekStart = 'week_start'; // '1'
  static const budgetMonthStartDay = 'budget_month_start_day'; // '1'
  static const nextNotifId = 'next_notif_id';
  static const captureDraft = 'capture_draft';
}

abstract interface class SettingsRepository {
  Stream<String?> watch(String key);
  Future<void> put(String key, String value);
  Future<int> nextNotificationId(); // atomic increment
}
