/// The words the ui/ widgets add themselves, in one place until the app has
/// localisation. Everything else is passed in by the screen.
abstract final class PulseStrings {
  static const save = 'Save';
  static const confirm = 'Confirm';
  static const edit = 'Edit';
  static const skip = 'Skip';
  static const undo = 'Undo';
  static const schedule = 'Schedule';
  static const bill = 'Bill';
  static const recurring = 'Recurring';
  static const noAmount = 'No amount';
  static const due = 'Due';
  static const dueToday = 'Due today';
  static const overdue = 'Overdue';
  static const highPriority = 'High priority';
  static const quickCapture = 'Quick capture';
  static const capturePlaceholder = 'Add money, a task or a note';
  static const parsedChips = 'What Pulse read';
  static const error = 'error';
  static const safeToSpend = 'Safe to spend today';
  static const setBudget = 'Set a budget to see safe-to-spend';
  static const spentToday = 'Spent today';
  static const liquidBalance = 'Liquid balance';
  static const wallets = 'Wallets';
  static const financialPulse = 'Financial pulse';
  static const capReached = 'Cap reached';

  static const expense = 'Expense';
  static const income = 'Income';
  static const transfer = 'Transfer';
  static const balance = 'Balance';
  static const minus = 'minus';

  static String complete(String title) => 'Complete $title';
  static String spent(String amount) => 'Spent $amount';
  static String left(String amount) => '$amount left';
  static String overBy(String amount) => 'Over by $amount';
  static String percentUsed(int percent) => '$percent% used';
  static String budgetOf(String category) => '$category budget';
  static String seconds(int s) => '$s s';
}
