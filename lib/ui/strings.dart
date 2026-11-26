/// The words the ui/ widgets add themselves, in one place until the app has
/// localisation. Everything else is passed in by the screen.
abstract final class MelaStrings {
  static const appName = 'MelaTime';
  static const tagline = 'Menata laku, setiap waktu.';
  static const save = 'Save';
  static const tomorrow = 'Tomorrow';
  static const yesterday = 'Yesterday';
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
  static const parsedChips = 'What MelaTime read';
  static const error = 'error';
  static const safeToSpend = 'Safe to spend today';
  static const setBudget = 'Set a budget to see safe-to-spend';
  static const spentToday = 'Spent today';
  static const liquidBalance = 'Liquid balance';
  static const wallets = 'Wallets';
  static const financialPulse = 'Financial pulse';
  static const capReached = 'Cap reached';

  // App shell and the placeholder screens.
  static const today = 'Today';
  static const tasks = 'Tasks';
  static const calendar = 'Calendar';
  static const notes = 'Notes';
  static const finance = 'Finance';
  static const search = 'Search';
  static const settings = 'Settings';
  static const back = 'Back';
  static const needsConfirmation = 'Needs confirmation';
  static const timeline = 'Timeline';
  static const priorityInbox = 'Priority inbox';
  static const scratchpad = 'Scratchpad';
  static const noTasks = 'No tasks yet';
  static const noEvents = 'Nothing scheduled';
  static const noNotes = 'No notes yet';
  static const noTransactions = 'No transactions yet';
  static const searchEmpty = 'Search your money, tasks and notes';
  static const settingsEmpty = 'No settings yet';
  static const noPulse = 'No money recorded yet';
  static const noTimeline = 'Nothing scheduled today';
  static const noInbox = 'Nothing in the inbox';
  static const noTimelineBody =
      'Add a time to a task and it shows up here, earliest first.';
  static const noInboxBody =
      'Overdue, high priority and due today tasks show up here.';
  static const noScratchpad = 'Nothing written today';
  static const captureEmpty = 'Quick capture is not ready yet';

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
