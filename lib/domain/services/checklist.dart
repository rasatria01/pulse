// Pure string rules for inline note tasks (PRD 9.2).
import 'dart:math';

/// One checklist line of a note body, outside fenced code blocks.
final class ChecklistLine {
  const ChecklistLine({
    required this.index,
    required this.checked,
    required this.title,
    this.blockId,
    this.token,
  });

  final int index; // zero-based line number in the body
  final bool checked;
  final String title; // without the ^t token

  /// 't' + 6 base36 chars, without the '^'. Null = new line, which includes a
  /// token already used by an earlier line of the same note.
  final String? blockId;

  /// The id as written, repeated or not.
  final String? token;
}

// Groups: indent and bullet, check mark, rest of the line.
final _item = RegExp(r'^(\s*[-*] )\[( |x|X)\] (.*)$');
// Matched anywhere on the line, so text typed after the token keeps identity.
final _token = RegExp(r'(?:^|\s+)\^(t[0-9a-z]{6})(?=\s|$)');
final _fence = RegExp(r'^\s*(`{3,}|~{3,})(.*)$');
// A token cut short or typed onto.
final _damaged = RegExp(r'(?:^|\s+)\^(t\S*)(?=\s|$)');
const _base36 = '0123456789abcdefghijklmnopqrstuvwxyz';

List<ChecklistLine> parseChecklist(String body) => _scan(body).$1;

/// The block ids after a code fence that is never closed. Their lines read as
/// code for now, which is not the same as removed.
Iterable<String> blockIdsInOpenFence(String body) {
  final open = _scan(body).$2;
  return open == null
      ? const []
      : blockIdsIn(body.split('\n').sublist(open).join('\n'));
}

/// The checklist lines, and the line of a fence still open at the end.
(List<ChecklistLine>, int?) _scan(String body) {
  final found = <ChecklistLine>[];
  final seen = <String>{};
  String? fence; // the opening run while inside a code block
  var opened = 0;
  final lines = body.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = _withoutCr(lines[i]);
    final f = _fence.firstMatch(line);
    if (fence != null) {
      // Closes on the same character, at least as long, with nothing after.
      if (f != null && f[1]!.startsWith(fence) && f[2]!.trim().isEmpty) {
        fence = null;
      }
      continue;
    }
    // A backtick in the info string makes it inline code, not a fence.
    if (f != null && !(f[1]!.startsWith('`') && f[2]!.contains('`'))) {
      fence = f[1];
      opened = i;
      continue;
    }
    final m = _item.firstMatch(line);
    if (m == null) continue;
    final id = _token.allMatches(m[3]!).lastOrNull?[1];
    found.add(
      ChecklistLine(
        index: i,
        checked: m[2] != ' ',
        title: m[3]!.replaceAll(_token, '').trim(),
        blockId: id != null && seen.add(id) ? id : null,
        token: id,
      ),
    );
  }
  return (found, fence == null ? null : opened);
}

/// Checklist lines that lost their block id to an edit: the token is a part of
/// one of [known], or one with more typed onto it. By line index, with the title
/// the repaired line gets (what was typed onto the token joins it).
Map<int, ({String blockId, String title})> damagedBlockIds(
  String body,
  Set<String> known,
) {
  final claimed = blockIdsIn(body).toSet();
  final lines = body.split('\n');
  final found = <int, ({String blockId, String title})>{};
  for (final line in parseChecklist(body)) {
    if (line.token != null) continue;
    final rest = _item.firstMatch(_withoutCr(lines[line.index]))![3]!;
    for (final m in _damaged.allMatches(rest)) {
      final word = m[1]!;
      final ids = known.where(
        (id) =>
            !claimed.contains(id) &&
            // 4: shorter says too little about which item it was.
            (word.length >= 4 && id.startsWith(word) || word.startsWith(id)),
      );
      if (ids.length != 1) continue;
      final id = ids.single;
      claimed.add(id);
      final extra = word.length > id.length ? word.substring(id.length) : '';
      found[line.index] = (
        blockId: id,
        title: '${rest.substring(0, m.start)}$extra${rest.substring(m.end)}'
            .trim(),
      );
      break;
    }
  }
  return found;
}

/// Where each checklist line's block id sits in [body], fenced or not: the line
/// starts at [lineStart], its text after the checkbox at [content], and the
/// token runs from its '^' at [hat] to [end].
Iterable<({int lineStart, int content, int hat, int end})> blockTokenSpans(
  String body,
) sync* {
  var lineStart = 0;
  for (final raw in body.split('\n')) {
    final line = _withoutCr(raw);
    final m = _item.firstMatch(line);
    if (m != null) {
      final content = lineStart + line.length - m[3]!.length;
      for (final t in _token.allMatches(m[3]!)) {
        final end = content + t.end;
        // '^' and the 7 characters of the id.
        yield (lineStart: lineStart, content: content, hat: end - 8, end: end);
      }
    }
    lineStart += raw.length + 1;
  }
}

/// Every block id written in [text].
Iterable<String> blockIdsIn(String text) =>
    _token.allMatches(text.replaceAll('\r', '')).map((m) => m[1]!);

/// [text] without its block ids, for reading.
String hideBlockIds(String text) => text.replaceAll(_token, '');

/// A block id not in [taken]. Pass every id of the note: those on its lines and
/// those of its items, deleted ones too (the unique index covers them).
String generateBlockId(Random random, Set<String> taken) {
  while (true) {
    final chars = List.generate(6, (_) => _base36[random.nextInt(36)]);
    final id = 't${chars.join()}';
    if (!taken.contains(id)) return id;
  }
}

/// Rewrites the checklist line at [index] as `- [ ] <title> ^t<id>`, keeping
/// its indent, bullet and line ending. The line count does not change.
String rewriteChecklistLine(
  String body,
  int index, {
  required bool checked,
  required String title,
  required String blockId,
}) {
  _requireChecklistLine(body, index);
  final lines = body.split('\n');
  final old = lines[index];
  final m = _item.firstMatch(_withoutCr(old))!;
  final mark = !checked ? ' ' : (m[2] == 'X' ? 'X' : 'x');
  final text = title.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  final cr = old.endsWith('\r') ? '\r' : '';
  lines[index] = '${m[1]}[$mark] ${text.isEmpty ? '' : '$text '}^$blockId$cr';
  return lines.join('\n');
}

/// Removes the checklist line at [index] together with its line break.
String removeChecklistLine(String body, int index) {
  _requireChecklistLine(body, index);
  final lines = body.split('\n')..removeAt(index);
  // The new last line must not keep half of a CRLF.
  if (index == lines.length && index > 0) {
    lines[index - 1] = _withoutCr(lines[index - 1]);
  }
  return lines.join('\n');
}

// A stale index must never overwrite or delete ordinary note text.
void _requireChecklistLine(String body, int index) {
  if (!parseChecklist(body).any((l) => l.index == index)) {
    throw ArgumentError.value(index, 'index', 'not a checklist line');
  }
}

String _withoutCr(String line) =>
    line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
