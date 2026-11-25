/// Quick capture copy (English; one place until the app has localisation).
abstract final class CaptureStrings {
  static const kind = 'Kind';
  static const amount = 'Amount';
  static const wallet = 'Wallet';
  static const fromWallet = 'From wallet';
  static const toWallet = 'To wallet';
  static const category = 'Category';
  static const date = 'Date';
  static const time = 'Time';
  static const priority = 'Priority';
  static const tags = 'Tags';

  static const transaction = 'Transaction';
  static const task = 'Task';
  static const note = 'Note';
  static const bill = 'Bill';

  static const addAmount = 'Add amount';
  static const invalidAmount = 'Invalid amount';
  static const pickWallet = 'Pick wallet';
  static const uncategorized = 'Uncategorized';
  static const now = 'Now';
  static const noDate = 'No date';
  static const noTag = 'Tag';

  static const noPriority = 'No priority';
  static const lowPriority = 'Low priority';
  static const medPriority = 'Medium priority';
  static const highPriority = 'High priority';

  static const timeError = 'Write the time as 14:30.';
  static const noTags = 'No tags yet. Type #name to add one.';
  static const amountError = 'That is not an amount. Try 35000 or 35k.';

  static const hintInvalidAmount =
      'That amount doesn’t work. Tap the chip to fix it.';
  static const hintMissingAmount = 'Add an amount. Tap the chip to enter one.';
  static const hintNoWallet = 'No wallet picked. Tap the chip to pick one.';
  static const hintSameWallet = 'A transfer needs two different wallets.';
  static const hintEmptyTitle = 'Add a title to save.';
  static const saveFailed = 'Couldn’t save. Try again.';
  static const undoFailed = 'Couldn’t undo.';

  static String unknownWallet(String typed) =>
      '$typed isn’t a wallet. Tap the chip to pick one.';
  static String archivedWallet(String name) =>
      '$name is archived. Tap the chip to pick another.';
  static String from(String wallet) => 'From $wallet';
  static String to(String wallet) => 'To $wallet';
  static String due(String day) => 'Due $day';

  static const aTransfer = 'transfer';
  static String quoted(String title) => '“$title”';
  static String savedTo(String what, String wallet) => 'Saved $what to $wallet';
  static String savedTask(String title) => 'Saved task ${quoted(title)}';
  static String savedNote(String title) => 'Saved note ${quoted(title)}';
}
