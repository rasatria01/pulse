/// Words of the task, schedule and bill pieces that Tasks, Calendar and Today
/// share (features can't import each other).
abstract final class PlannerStrings {
  static const newTask = 'New task';
  static const editTask = 'Edit task';
  static const addTask = 'Add task';
  static const title = 'Title';
  static const titlePlaceholder = 'What needs doing';
  static const priority = 'Priority';
  static const dueDate = 'Due date';
  static const scheduleDate = 'Schedule';
  static const startTime = 'Start time';
  static const duration = 'Duration';
  static const reminder = 'Reminder';
  static const tags = 'Tags';
  static const tagsPlaceholder = '#home #admin';
  static const none = 'None';
  static const noEnd = 'No end';
  static const atStart = 'At start';
  static const today = 'Today';
  static const tomorrow = 'Tomorrow';
  static const yesterday = 'Yesterday';
  static const pickDate = 'Pick date';
  static const delete = 'Delete';
  static const complete = 'Complete';
  static const reopen = 'Reopen';
  static const close = 'Close';
  static const done = 'Done';
  static const low = 'Low';
  static const medium = 'Medium';
  static const high = 'High';
  static const needsTitle = 'Add a title.';
  static const badTime = 'Use a 24-hour time, such as 09:00.';
  static const badTags = 'Tags use letters, numbers, - and _.';

  static const recordPayment = 'Record payment';
  static const amount = 'Amount (Rp)';
  static const wallet = 'Wallet';
  static const category = 'Category';
  static const description = 'Description';
  static const needsAmount = 'Add an amount to record this bill.';
  static const reopenBill = 'Reopen bill';
  static const keepPayment = 'Keep payment';
  static const deletePayment = 'Delete payment';
  static const recordRecurring = 'Record transaction';
  static const needsRecurringAmount = 'Add an amount above 0.';
  static const archivedRuleWallet =
      'That wallet is archived. Change the wallet on the recurring rule.';
  static const failed = 'Couldn’t make that change. Try again.';

  static String fromWallet(String wallet) => 'Wallet: $wallet';
  static String skippedOccurrence(String name) => 'Skipped “$name”';
  static String paymentRecorded(String amount) =>
      'A payment of $amount is recorded for this bill.';
  static String completed(String title) => 'Completed “$title”';
  static String deleted(String title) => 'Deleted “$title”';
  static String scheduled(String title, String when) =>
      'Scheduled “$title” for $when';
  static String recorded(
    String title,
    String amount,
    String wallet, {
    bool income = false,
  }) => 'Recorded “$title”, $amount ${income ? 'to' : 'from'} $wallet';
  static String deferred(String title) =>
      'Moved “$title” to Needs confirmation';
  static String skipped(String title) => 'Skipped payment for “$title”';
  static String minutes(int n) => '$n min';
  static String hours(int n) => '$n h';
  static String days(int n) => n == 1 ? '1 day' : '$n days';
  static String before(String span) => '$span before';
  static String overdueBy(int days) => 'Overdue · ${PlannerStrings.days(days)}';
  static String due(String date) => 'Due $date';
}
