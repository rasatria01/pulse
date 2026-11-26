abstract final class NotesStrings {
  static const newNote = 'Add note';
  static const note = 'Note';
  static const untitled = 'Untitled';
  static const todayScratchpad = 'Today’s scratchpad';
  static const writeSomething = 'Start writing';
  static const heading = 'Heading';
  static const bold = 'Bold';
  static const italic = 'Italic';
  static const checklist = 'Checklist';
  static const code = 'Code';
  static const preview = 'Preview';
  static const edit = 'Edit';
  static const delete = 'Delete note';
  static const deleted = 'Deleted note';
  static const notFound = 'This note was deleted. Go back to Notes.';
  static const deleteFailed = 'Couldn’t delete the note. Try again.';
  static const saveFailed = 'Couldn’t save the note. Try again.';
  static const syncFailed =
      'Saved, but the checklist didn’t sync. Edit the note to retry.';
  static const restoreFailed = 'Couldn’t restore the note. Try again.';
  static const emptyPreview = 'Nothing to preview';
  static const done = 'Done';
  static const notDone = 'Not done';
  static String scratchpad(String day) => 'Scratchpad · $day';
}
