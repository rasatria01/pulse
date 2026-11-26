// Highlighting, toolbar, merge and cursor mapping: pure functions.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/notes/markdown_editing.dart';
import 'package:pulse/features/notes/note_merge.dart';

const _styles = (
  heading: TextStyle(fontSize: 1),
  marker: TextStyle(fontSize: 2),
  code: TextStyle(fontSize: 3),
  token: TextStyle(fontSize: 4),
);

/// "a|b" is a cursor, "a[b]c" a selection.
TextEditingValue _value(String marked) {
  final cursor = marked.indexOf('|');
  if (cursor >= 0) {
    return TextEditingValue(
      text: marked.replaceFirst('|', ''),
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
  final start = marked.indexOf('«'), end = marked.indexOf('»');
  return TextEditingValue(
    text: marked.replaceAll('«', '').replaceAll('»', ''),
    selection: TextSelection(baseOffset: start, extentOffset: end - 1),
  );
}

void main() {
  test('highlighting round-trips the text exactly', () {
    const text =
        '# Title\r\n\n- [ ] Buy **milk** *now* `x` ^t7f3k2a\r\n'
        '  * [x] done\n> quote\n1. one\n```dart\n- [ ] ^t000000\n```\n'
        '~~~\nopen **fence\n  trailing   \t';
    for (final source in [text, '', '\n', '**', 'a ^t12', '😀 **é**']) {
      final spans = highlightMarkdown(source, _styles);
      expect(TextSpan(children: spans).toPlainText(), source);
    }
    expect(
      highlightMarkdown(
        text,
        _styles,
      ).where((s) => s.style == _styles.token).map((s) => s.text),
      ['^t7f3k2a'],
    );
  });

  test('toolbar', () {
    void check(MarkdownAction action, String before, String after) =>
        expect(applyMarkdown(_value(before), action), _value(after));

    check(MarkdownAction.bold, 'a «word» b', 'a **«word»** b');
    check(MarkdownAction.bold, 'a **«word»** b', 'a «word» b');
    check(MarkdownAction.bold, 'a |', 'a **|**');
    check(MarkdownAction.italic, '**«w»**', '***«w»***');
    check(MarkdownAction.italic, '*«w»*', '«w»');
    check(MarkdownAction.code, '«x»', '`«x»`');
    check(MarkdownAction.code, '«a\nb»', '```\n«a\nb»\n```');
    check(MarkdownAction.heading, 'x\nTit|le', 'x\n# Tit|le');
    check(MarkdownAction.heading, '# Tit|le', 'Tit|le');
    check(MarkdownAction.checklist, 'Mi|lk', '- [ ] Mi|lk');
    check(MarkdownAction.checklist, '  - Mi|lk', '  - [ ] Mi|lk');
    check(MarkdownAction.checklist, '- [ ] Mi|lk', 'Mi|lk');
    check(MarkdownAction.checklist, 'a\n|', 'a\n- [ ] |');
  });

  test('merge: a write-back keeps what was typed meanwhile', () {
    const base = 'top\n- [ ] a ^t000001\nend';
    expect(
      mergeBody(base, 'top\n- [ ] a ^t000001\nend more', 'top\nend'),
      'top\nend more',
    );
    expect(
      mergeBody(
        base,
        'new\ntop\n- [ ] a ^t000001\nend',
        'top\n- [x] a ^t000001\nend',
      ),
      'new\ntop\n- [x] a ^t000001\nend',
    );
    // A new id must reach a line that was edited while it was being saved.
    expect(
      mergeBody('- [ ] a', '- [ ] ab', '- [ ] a ^t000002'),
      '- [ ] ab ^t000002',
    );
    expect(mergeBody('a', 'a', 'b'), 'b');
  });

  test('the cursor stays with its text', () {
    // Same line, token added after it.
    expect(mapOffset('- [ ] Buy', '- [ ] Buy ^t000001', 9), 9);
    // Checkbox rewritten before the cursor.
    expect(mapOffset('- [ ] Buy', '- [x] Buy', 9), 9);
    // A line above it changed length, then one was removed.
    expect(mapOffset('a\nend', 'a ^t000001\nend', 4), 13);
    expect(mapOffset('top\n- [ ] a\nend', 'top\nend', 15), 7);
    // Words consumed in front of the cursor.
    expect(mapOffset('buy besok milk', 'buy milk', 14), 8);
  });
}
