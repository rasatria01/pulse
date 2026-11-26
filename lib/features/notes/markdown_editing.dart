// Source-mode editing: highlighting that keeps the text exact, and the toolbar.
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

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
