// Source-mode editing: highlighting that keeps the text exact, the toolbar, and
// the guard that keeps task tokens whole.
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../domain/services/checklist.dart';
import '../../ui/theme.dart';

typedef MarkdownStyles = ({
  TextStyle heading,
  TextStyle marker,
  TextStyle code,
  TextStyle token,
});

const _bold = TextStyle(
  fontWeight: FontWeight.w700,
  fontVariations: [FontVariation('wght', 700)],
);
const _italic = TextStyle(fontStyle: FontStyle.italic);

/// A controller that colours Markdown source without changing a character.
class MarkdownController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = ShadTheme.of(context).colorScheme;
    return TextSpan(
      style: style,
      children: highlightMarkdown(text, (
        heading: _bold,
        marker: TextStyle(color: colors.mutedForeground),
        code: TextStyle(color: colors.positive, fontFamily: 'monospace'),
        token: TextStyle(color: colors.inkSubtle.withValues(alpha: 0.6)),
      )),
    );
  }
}

final _fence = RegExp(r'^\s*(```|~~~)');
final _heading = RegExp(r'^#{1,6}\s');
// A list marker, with its checkbox if it has one, or a quote mark.
final _lead = RegExp(r'^\s*(?:(?:[-*+]|\d+\.) (?:\[[ xX]\] )?|> ?)');
final _inline = RegExp(
  r'(\*\*[^*\n]+\*\*)|(\*[^*\s][^*\n]*\*)|(`[^`\n]+`)'
  r'|((?<=\s)\^t[0-9a-z]{6}(?=\s|$))',
);

/// Spans whose texts join back to exactly [text].
List<TextSpan> highlightMarkdown(String text, MarkdownStyles styles) {
  final spans = <TextSpan>[];
  void add(String part, [TextStyle? style]) {
    if (part.isNotEmpty) spans.add(TextSpan(text: part, style: style));
  }

  var fenced = false;
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) add('\n');
    final line = lines[i];
    if (_fence.hasMatch(line)) {
      fenced = !fenced;
      add(line, styles.code);
    } else if (fenced) {
      add(line, styles.code);
    } else if (_heading.hasMatch(line)) {
      add(line, styles.heading);
    } else {
      var at = _lead.firstMatch(line)?.end ?? 0;
      add(line.substring(0, at), styles.marker);
      for (final m in _inline.allMatches(line, at)) {
        add(line.substring(at, m.start));
        add(
          m[0]!,
          m[1] != null
              ? _bold
              : m[2] != null
              ? _italic
              : m[3] != null
              ? styles.code
              : styles.token,
        );
        at = m.end;
      }
      add(line.substring(at));
    }
  }
  return spans;
}

enum MarkdownAction { heading, bold, italic, checklist, code }

/// The toolbar's edit of [value]; the selection follows the text.
TextEditingValue applyMarkdown(TextEditingValue value, MarkdownAction action) {
  final text = value.text;
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: text.length);
  final start = selection.start, end = selection.end;

  TextEditingValue wrap(String open, [String? close]) {
    final shut = close ?? open;
    final before = text.substring(0, start), after = text.substring(end);
    // A second tap takes the marks off. "**" around is bold, not italic.
    final wrapped =
        before.endsWith(open) &&
        after.startsWith(shut) &&
        !(open == '*' && before.endsWith('**') && !before.endsWith('***'));
    final inside = text.substring(start, end);
    final head = wrapped
        ? before.substring(0, before.length - open.length)
        : '$before$open';
    final tail = wrapped ? after.substring(shut.length) : '$shut$after';
    return TextEditingValue(
      text: '$head$inside$tail',
      selection: TextSelection(
        baseOffset: head.length,
        extentOffset: head.length + inside.length,
      ),
    );
  }

  // Toggles a marker at the start of the cursor's line.
  TextEditingValue prefix(String marker, RegExp present) {
    final from = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final old = present.firstMatch(text.substring(from))?[0] ?? '';
    final indent = old.length - old.trimLeft().length;
    // A checklist replaces a plain bullet instead of stacking on it.
    final next = old.trimLeft() == marker ? '' : marker;
    final head = '${text.substring(0, from + indent)}$next';
    final cut = from + old.length;
    int move(int offset) => offset >= cut
        ? offset - cut + head.length
        : offset < from
        ? offset
        : head.length;
    return TextEditingValue(
      text: '$head${text.substring(cut)}',
      selection: TextSelection(
        baseOffset: move(selection.baseOffset),
        extentOffset: move(selection.extentOffset),
      ),
    );
  }

  return switch (action) {
    MarkdownAction.heading => prefix('# ', RegExp(r'^(#{1,6} )?')),
    MarkdownAction.checklist => prefix(
      '- [ ] ',
      RegExp(r'^[ \t]*([-*] (\[[ xX]\] )?)?'),
    ),
    MarkdownAction.bold => wrap('**'),
    MarkdownAction.italic => wrap('*'),
    MarkdownAction.code =>
      text.substring(start, end).contains('\n')
          ? wrap('```\n', '\n```')
          : wrap('`'),
  };
}

/// A task line's `^t` token is the item's identity, so typing treats it as one
/// piece: an edit that reaches into it applies before it, and it goes only with
/// its whole line.
class BlockIdGuard extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => keepBlockIds(oldValue, newValue);
}

/// [next] as typed over [old], corrected to leave every token whole.
TextEditingValue keepBlockIds(TextEditingValue old, TextEditingValue next) {
  final text = old.text, after = next.text;
  if (text == after) return next;
  final spans = blockTokenSpans(text).toList();
  if (spans.isEmpty) return next;

  // The replaced range [a, b) and what went in. The cursor settles which of two
  // equal characters was typed or removed.
  final most = min(text.length, after.length);
  var limit = most;
  if (old.selection.isValid && next.selection.isValid) {
    limit = min(limit, min(old.selection.start, next.selection.end));
  }
  var a = 0;
  while (a < limit && text[a] == after[a]) {
    a++;
  }
  var tail = 0;
  while (tail < most - a &&
      text[text.length - 1 - tail] == after[after.length - 1 - tail]) {
    tail++;
  }
  final b = text.length - tail;
  final typed = after.substring(a, after.length - tail);
  final newline = typed.contains('\n');

  TextEditingValue value(String result, int cursor) => TextEditingValue(
    text: result,
    selection: TextSelection.collapsed(offset: cursor),
  );
  TextEditingValue insert(int at, [String pad = '']) => value(
    '${text.substring(0, at)}$typed$pad${text.substring(at)}',
    at + typed.length,
  );

  if (a == b) {
    for (final t in spans) {
      if (a > t.end || a < t.content - 1) continue;
      // A new line must not carry the token away from its title.
      if (newline) {
        final carries =
            a < t.end &&
            (a >= t.hat || text.substring(a, t.hat).trim().isEmpty);
        if (carries) return insert(t.end);
        continue;
      }
      if (a < t.hat) continue;
      if (a == t.end && typed.startsWith(RegExp(r'\s'))) continue;
      if (a == t.hat && typed.endsWith(' ')) continue;
      // An empty title: keep the space after the checkbox.
      return text[t.hat - 2] == ']' ? insert(t.hat, ' ') : insert(t.hat - 1);
    }
    return next;
  }

  // Where each touched token's protected part starts: the '^', or also the one
  // space that separates it.
  int guard(int hat) => text[hat - 2].trim().isEmpty ? hat : hat - 1;
  final touched = [
    for (final t in spans)
      if (a < t.end && b > guard(t.hat) && !(a <= t.lineStart && b >= t.end)) t,
  ];
  if (touched.isEmpty) return next;

  final first = touched.first;
  if (typed.isEmpty && a >= guard(first.hat) && b <= first.end) {
    // Backspace takes the title's last character instead; the rest does nothing.
    final backspace = old.selection.isCollapsed && old.selection.start == b;
    final end = first.hat - 1;
    if (!backspace || end <= first.content) return old;
    final title = text.substring(first.content, end);
    final left = title.characters.skipLast(1).toString();
    return value(
      '${text.substring(0, first.content)}$left${text.substring(end)}',
      first.content + left.length,
    );
  }

  var from = a, to = b;
  final kept = StringBuffer();
  for (final t in touched) {
    if (from > t.hat - 1) from = t.hat - 1;
    // The checkbox stays with the token that is staying.
    if (from >= t.lineStart && from < t.content - 1) from = t.content;
    kept.write(text.substring(t.hat - 1, t.end));
    to = max(to, t.end);
  }
  final middle = newline ? '$kept$typed' : '$typed$kept';
  return value(
    '${text.substring(0, from)}$middle${text.substring(to)}',
    from + (newline ? middle.length : typed.length),
  );
}

/// [value] with the cursor or selection moved out of any token, for the toolbar.
TextEditingValue outsideBlockIds(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) return value;
  final spans = blockTokenSpans(value.text).toList();
  int move(int offset) {
    for (final t in spans) {
      if (offset >= t.hat && offset <= t.end) {
        return max(t.content, t.hat - 1);
      }
    }
    return offset;
  }

  return value.copyWith(
    selection: TextSelection(
      baseOffset: move(selection.baseOffset),
      extentOffset: move(selection.extentOffset),
    ),
  );
}
