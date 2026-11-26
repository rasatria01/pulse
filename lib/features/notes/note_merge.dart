// A write-back into text that is open in the editor: merge by line, keep the
// cursor. Pure.
import 'dart:math';

import '../../domain/services/checklist.dart';

/// How many items at the start of [a] and [b] are equal.
int _commonStart<T>(List<T> a, List<T> b) {
  var n = 0;
  while (n < min(a.length, b.length) && a[n] == b[n]) {
    n++;
  }
  return n;
}

/// The same at the end, not reaching into the first [skip] items.
int _commonEnd<T>(List<T> a, List<T> b, int skip) {
  var n = 0;
  while (n < min(a.length, b.length) - skip &&
      a[a.length - 1 - n] == b[b.length - 1 - n]) {
    n++;
  }
  return n;
}

/// [mine] with the change from [base] to [theirs] applied. The change is a
/// rewrite of some lines, or one block of lines removed or put back.
String mergeBody(String base, String mine, String theirs) {
  if (mine == base) return theirs;
  if (theirs == base) return mine;
  final b = base.split('\n'), m = mine.split('\n'), t = theirs.split('\n');
  // Where a base line is now: same place, else same text, else same block id.
  int find(int i) {
    if (i < m.length && m[i] == b[i]) return i;
    final same = m.indexOf(b[i]);
    if (same >= 0) return same;
    final id = blockIdsIn(b[i]).lastOrNull;
    return id == null ? -1 : m.indexWhere((l) => blockIdsIn(l).contains(id));
  }

  if (t.length == b.length) {
    for (var i = 0; i < b.length; i++) {
      if (b[i] == t[i]) continue;
      final at = find(i);
      if (at >= 0 && m[at] == b[i]) {
        m[at] = t[i];
        continue;
      }
      // The line was edited meanwhile: keep the edit, but not lose a new id,
      // or the next save would make a second item.
      final id = blockIdsIn(t[i]).lastOrNull;
      final target = at >= 0 ? at : min(i, m.length - 1);
      if (id != null &&
          !m.any((l) => blockIdsIn(l).contains(id)) &&
          blockIdsIn(m[target]).isEmpty) {
        m[target] = '${m[target]} ^$id';
      }
    }
  } else {
    final head = _commonStart(b, t);
    final tail = _commonEnd(b, t, head);
    for (var i = b.length - tail - 1; i >= head; i--) {
      final at = find(i);
      if (at >= 0) m.removeAt(at);
    }
    m.insertAll(min(head, m.length), t.sublist(head, t.length - tail));
  }
  return m.join('\n');
}

/// Where [offset] of [before] lands in [after], staying on its line and next to
/// the same characters.
int mapOffset(String before, String after, int offset) {
  if (offset < 0) return offset;
  final a = before.split('\n'), b = after.split('\n');
  var line = 0, column = min(offset, before.length);
  while (column > a[line].length) {
    column -= a[line].length + 1;
    line++;
  }
  var target = line;
  if (a.length != b.length && line >= _commonStart(a, b)) {
    target = line + b.length - a.length;
  }
  target = target.clamp(0, b.length - 1);

  final old = a[line].split(''), now = b[target].split('');
  final same = _commonStart(old, now);
  if (column > same) {
    column = column >= old.length - _commonEnd(old, now, same)
        ? now.length - (old.length - column)
        : min(column, now.length);
  }
  for (var i = 0; i < target; i++) {
    column += b[i].length + 1;
  }
  return column;
}
