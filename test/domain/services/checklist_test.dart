import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/domain/services/checklist.dart';

List<(int, bool, String, String?)> _parse(String body) => [
  for (final l in parseChecklist(body))
    (l.index, l.checked, l.title, l.blockId),
];

void main() {
  test('reads state, title and token', () {
    const body =
        '# Shop\n'
        '- [ ] Buy milk ^t7f3k2a\n'
        '  * [x] eggs\n'
        '- [X] ^tabc123';
    expect(_parse(body), [
      (1, false, 'Buy milk', 't7f3k2a'),
      (2, true, 'eggs', null),
      (3, true, '', 'tabc123'),
    ]);
  });

  test('ignores lines that do not match the PRD pattern', () {
    const body =
        '- [] a\n-[ ] b\n+ [ ] c\n- [ ]d\n1. [ ] e\nx - [ ] f\n- [y] g';
    expect(_parse(body), isEmpty);
  });

  test('text typed after the token keeps the identity', () {
    expect(_parse('- [ ] Buy milk ^t7f3k2a besok'), [
      (0, false, 'Buy milk besok', 't7f3k2a'),
    ]);
  });

  test('malformed tokens stay in the title', () {
    for (final text in [
      'a ^t7f3k2',
      'a ^t7f3k2ab',
      'a^t7f3k2a',
      'a ^T7F3K2A',
    ]) {
      expect(_parse('- [ ] $text'), [(0, false, text, null)], reason: text);
    }
  });

  test('skips fenced code blocks', () {
    const body =
        '```dart\n- [ ] in backticks\n~~~\n```\n'
        '- [ ] one\n'
        '  ~~~~\n- [ ] in tildes\n~~~\n- [ ] still in\n  ~~~~\n'
        '- [ ] two\n'
        '```inline``` is not a fence\n'
        '- [ ] three\n'
        '```\n- [ ] unclosed';
    expect(
      [for (final l in parseChecklist(body)) l.title],
      ['one', 'two', 'three'],
    );
  });

  test('a duplicated token is new on its second occurrence', () {
    expect(_parse('- [ ] a ^t7f3k2a\n- [ ] b ^t7f3k2a'), [
      (0, false, 'a', 't7f3k2a'),
      (1, false, 'b', null),
    ]);
    // A token inside a code block does not count as the first occurrence.
    expect(_parse('```\n- [ ] a ^t7f3k2a\n```\n- [ ] b ^t7f3k2a'), [
      (3, false, 'b', 't7f3k2a'),
    ]);
  });

  test('block ids are t + 6 base36 and avoid taken ones', () {
    final first = generateBlockId(Random(1), {});
    expect(first, matches(r'^t[0-9a-z]{6}$'));
    expect(generateBlockId(Random(1), {}), first);
    expect(generateBlockId(Random(1), {first}), isNot(first));
  });

  test('rewrite keeps indent, bullet, CRLF and the other lines', () {
    expect(
      rewriteChecklistLine(
        'a\r\n  * [ ] milk besok\r\nb',
        1,
        checked: false,
        title: 'milk',
        blockId: 't7f3k2a',
      ),
      'a\r\n  * [ ] milk ^t7f3k2a\r\nb',
    );
  });

  test('rewrite replaces a duplicate token and sets the check mark', () {
    final body = rewriteChecklistLine(
      '- [ ] a ^t7f3k2a\n- [ ] b ^t7f3k2a',
      1,
      checked: true,
      title: 'b\nc',
      blockId: 'tnew000',
    );
    expect(body, '- [ ] a ^t7f3k2a\n- [x] b c ^tnew000');
    expect(_parse(body).last, (1, true, 'b c', 'tnew000'));
  });

  test('rewrite keeps an uppercase X and handles an empty title', () {
    expect(
      rewriteChecklistLine(
        '- [X] old ^t7f3k2a',
        0,
        checked: true,
        title: '',
        blockId: 't7f3k2a',
      ),
      '- [X] ^t7f3k2a',
    );
  });

  test('remove takes the line and its break', () {
    expect(removeChecklistLine('a\n- [ ] b\nc', 1), 'a\nc');
    expect(removeChecklistLine('a\n- [ ] b\n', 1), 'a\n');
    expect(removeChecklistLine('a\r\n- [ ] b', 1), 'a');
    expect(removeChecklistLine('- [ ] b', 0), '');
  });

  test('a stale index never touches ordinary or fenced text', () {
    const body = 'a\n```\n- [ ] code\n```';
    for (final i in [0, 2, 9]) {
      expect(() => removeChecklistLine(body, i), throwsArgumentError);
      expect(
        () => rewriteChecklistLine(
          body,
          i,
          checked: true,
          title: 't',
          blockId: 't000000',
        ),
        throwsArgumentError,
      );
    }
  });
}
