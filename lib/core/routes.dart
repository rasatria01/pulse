/// Route paths. Here so features can navigate without importing app/.
abstract final class Routes {
  static const today = '/';
  static const tasks = '/tasks';
  static const calendar = '/calendar';
  static const notes = '/notes';

  static String notePath(String id) => '/notes/$id';

  /// Editor ids for a note that does not exist yet: it is created on the first
  /// keystroke.
  static const newNoteId = 'new';
  static const dailyNotePrefix = 'daily-'; // + 'YYYY-MM-DD'
  static const finance = '/finance';
  static const financeSummary = '/finance/summary';
  static const search = '/search';
  static const settings = '/settings';
  static const gallery = '/gallery';
}
