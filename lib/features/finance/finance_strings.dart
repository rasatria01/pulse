/// Finance copy (English; one place until the app has localisation).
abstract final class FinanceStrings {
  static const wallets = 'Wallets';
  static const transactions = 'Transactions';
  static const addWallet = 'Add wallet';
  static const editWallet = 'Edit wallet';
  static const transfer = 'Transfer';
  static const showArchived = 'Show archived';
  static const hideArchived = 'Hide archived';
  static const showOlder = 'Show older';
  static const loadError = 'Couldn’t load your money.';

  static const name = 'Name';
  static const handle = 'Handle';
  static const aliases = 'Other handles';
  static const startingBalance = 'Starting balance';
  static const type = 'Type';
  static const colour = 'Colour';
  static const includeInTotal = 'Include in total';
  static const setDefault = 'Set default';
  static const archive = 'Archive';
  static const confirmArchive = 'Confirm archive';
  static const archiveWarning =
      'An archived wallet keeps its history, takes no new transactions and '
      'can’t be restored.';

  static const cash = 'Cash';
  static const bank = 'Bank';
  static const ewallet = 'E-wallet';
  static const other = 'Other';

  static const isDefault = 'Default';
  static const archived = 'Archived';
  static const notInTotal = 'Not in total';

  static const nameError = 'Add a name.';
  static const handleError = 'Use letters, digits, _ or - in a handle.';
  static const balanceError = 'Write the balance as 50000, 50k or -50000.';
  static const saveFailed = 'Couldn’t save. Try again.';
  static String handleTaken(String slug) => '@$slug is already used.';

  static const editTransaction = 'Edit transaction';
  static const newTransfer = 'New transfer';
  static const amount = 'Amount';
  static const wallet = 'Wallet';
  static const fromWallet = 'From wallet';
  static const toWallet = 'To wallet';
  static const category = 'Category';
  static const uncategorized = 'Uncategorized';
  static const description = 'Description';
  static const date = 'Date';
  static const time = 'Time';
  static const timeError = 'Write the time as 14:30.';
  static const delete = 'Delete';
  static const confirmDelete = 'Confirm delete';
  static const deleted = 'Deleted transaction';
  static const amountError = 'Enter an amount above 0, such as 35000.';
  static const walletError = 'Pick a wallet.';
  static const transferError = 'A transfer needs two different wallets.';

  static const budgets = 'Budgets';
  static const addBudget = 'Add budget';
  static const editBudget = 'Budget cap';
  static const monthlyCap = 'Monthly cap';
  static const removeCap = 'Remove cap';
  static const capNote =
      'Applies from this budget month on. Earlier months keep their cap.';
  static const capError = 'Enter a cap above 0, such as 1500000.';
  static const categoryError = 'Pick a category.';

  static const recurring = 'Recurring';
  static const addRecurring = 'Add recurring';
  static const editRecurring = 'Recurring rule';
  static const repeats = 'Repeats';
  static const every = 'Every';
  static const daily = 'Daily';
  static const weekly = 'Weekly';
  static const monthly = 'Monthly';
  static const yearly = 'Yearly';
  static const startDate = 'Starts';
  static const endDate = 'Ends';
  static const whenDue = 'When due';
  static const remind = 'Ask me';
  static const autoPost = 'Post automatically';
  static const paused = 'Paused';
  static const ended = 'Ended';
  static const pause = 'Pause';
  static const resume = 'Resume';
  static const intervalError = 'Repeat every 1 to 999.';
  static const endError = 'The end date is before the start date.';
  static const days = 'days';
  static const weeks = 'weeks';
  static const months = 'months';
  static const years = 'years';
  static String next(String day) => 'Next $day';
  static String everyN(int n, String unit) => 'Every $n $unit';

  /// In the order of PulseIdentity.all.
  static const colourNames = [
    'Slate',
    'Blue',
    'Sky',
    'Teal',
    'Green',
    'Olive',
    'Amber',
    'Orange',
    'Rose',
    'Violet',
  ];
}
