import '../../core/local_date.dart';
import '../../domain/entities/note.dart';
import '../db/app_database.dart';
import 'column_values.dart';

/// How much of a line becomes a title or preview.
const _maxLine = 200;

// Heading, quote, bullet and checkbox markers at the start of a line.
final _marker = RegExp(r'^\s*(#{1,6}\s+|>\s*|[-*+]\s+(\[[ xX]\]\s*)?)');
final _blockId = RegExp(r'(^|\s)\^t[0-9a-z]{6}(?=\s|$)');

/// The non-blank lines of a Markdown body as plain text, markers and block ids
/// removed.
Iterable<String> _plainLines(String body) => body
    .split('\n')
    .map((l) => l.replaceFirst(_marker, '').replaceAll(_blockId, '').trim())
    .where((l) => l.isNotEmpty);

String _cut(String text) => text.length <= _maxLine
    ? text
    : String.fromCharCodes(text.runes.take(_maxLine));

/// The title a note without its own gets: the first line of its body.
String titleFromBody(String body) => _cut(_plainLines(body).firstOrNull ?? '');

/// [head] is the start of the body, enough for a preview.
NoteSummary noteSummary(NoteRow row, {required String head}) {
  var lines = _plainLines(head);
  // Do not repeat a title that came from the first line.
  if (lines.isNotEmpty && _cut(lines.first) == row.title) lines = lines.skip(1);
  final date = row.dailyDate;
  return NoteSummary(
    id: row.id,
    title: row.title,
    preview: _cut(lines.join(' ')),
    kind: NoteKind.values.byName(row.kind),
    dailyDate: date == null ? null : LocalDate.parse(date),
    isPinned: row.isPinned == 1,
    updatedAt: instant(row.updatedAt),
  );
}

extension NoteRowMapper on NoteRow {
  Note toEntity({List<String> tagIds = const []}) {
    final date = dailyDate;
    return Note(
      id: id,
      title: title,
      body: body,
      kind: NoteKind.values.byName(kind),
      dailyDate: date == null ? null : LocalDate.parse(date),
      isPinned: isPinned == 1,
      tagIds: tagIds,
      createdAt: instant(createdAt),
      updatedAt: instant(updatedAt),
    );
  }
}
