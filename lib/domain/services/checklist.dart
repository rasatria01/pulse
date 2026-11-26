// Pure string rules for inline note tasks (PRD 9.2).
import 'dart:math';

/// One checklist line of a note body, outside fenced code blocks.
final class ChecklistLine {
  const ChecklistLine({
    required this.index,
    required this.checked,
    required this.title,
    this.blockId,
  });

  final int index; // zero-based line number in the body
  final bool checked;
  final String title; // without the ^t token

  /// 't' + 6 base36 chars, without the '^'. Null = new line, which includes a
  /// token already used by an earlier line of the same note.
  final String? blockId;
}

// Groups: indent and bullet, check mark, rest of the line.
final _item = RegExp(r'^(\s*[-*] )\[( |x|X)\] (.*)$');
// Matched anywhere on the line, so text typed after the token keeps identity.
final _token = RegExp(r'(?:^|\s+)\^(t[0-9a-z]{6})(?=\s|$)');
final _fence = RegExp(r'^\s*(`{3,}|~{3,})(.*)$');
const _base36 = '0123456789abcdefghijklmnopqrstuvwxyz';

List<ChecklistLine> parseChecklist(String body) {
  final found = <ChecklistLine>[];
  final seen = <String>{};
  String? fence; // the opening run while inside a code block
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
      ),
    );
  }
  return found;
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
