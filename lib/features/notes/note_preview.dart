import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/local_date.dart';
import '../../domain/entities/action_item.dart';
import '../../domain/services/checklist.dart';
import '../../ui/planner/planner_format.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/widgets.dart';
import 'notes_strings.dart';

/// The rendered note. Checklist lines are drawn here, so that block ids stay
/// hidden and a synced item's date shows as a chip; the rest is Markdown.
class NotePreview extends ConsumerWidget {
  const NotePreview({super.key, required this.body, this.noteId});

  final String body;
  final String? noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = noteId;
    final items = id == null
        ? const <ActionItem>[]
        : ref.watch(noteItemsProvider(id)).value ?? const <ActionItem>[];
    final byBlock = {for (final i in items) i.sourceBlockId: i};
    final today = ref.watch(todayProvider);
    final colors = ShadTheme.of(context).colorScheme;
    final lines = body.split('\n');

    // Runs of Markdown (String) between checklist lines (ChecklistLine).
    final blocks = <Object>[];
    var from = 0;
    void markdown(int to) {
      final chunk = lines.sublist(from, to).join('\n');
      if (chunk.trim().isNotEmpty) blocks.add(chunk);
    }

    for (final line in parseChecklist(body)) {
      markdown(line.index);
      blocks.add(line);
      from = line.index + 1;
    }
    markdown(lines.length);

    if (blocks.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.eye,
        title: NotesStrings.emptyPreview,
      );
    }

    final text = PulseText.body.copyWith(color: colors.foreground);
    final panel = BoxDecoration(
      color: colors.muted,
      borderRadius: BorderRadius.circular(PulseRadius.md),
    );
    final style = MarkdownStyleSheet(
      p: text,
      listBullet: text,
      h1: PulseText.titleLg.copyWith(color: colors.foreground),
      h2: PulseText.title.copyWith(color: colors.foreground),
      h3: PulseText.bodyStrong.copyWith(color: colors.foreground),
      a: text.copyWith(decoration: TextDecoration.underline),
      code: text.copyWith(fontFamily: 'monospace', color: colors.positive),
      codeblockDecoration: panel,
      blockquoteDecoration: panel,
    );
    Widget render(String data) => MarkdownBody(
      data: data,
      styleSheet: style,
      // Offline app: never fetch an image, or read a file a note names.
      imageBuilder: (uri, title, alt) => Text(alt ?? '', style: text),
      checkboxBuilder: (checked) =>
          Icon(checked ? LucideIcons.squareCheck : LucideIcons.square),
    );

    return ListView.builder(
      padding: const EdgeInsets.all(PulseSpace.s4),
      itemCount: blocks.length,
      itemBuilder: (context, i) {
        final block = blocks[i];
        if (block is! ChecklistLine) return render(block as String);
        final item = byBlock[block.blockId];
        final date = item == null ? null : _date(item, today);
        final source = lines[block.index];
        final indent = source.length - source.trimLeft().length;
        return Padding(
          padding: EdgeInsets.only(
            left: indent * PulseSpace.s2,
            bottom: PulseSpace.s1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: PulseSpace.s2,
            children: [
              Icon(
                block.checked ? LucideIcons.squareCheck : LucideIcons.square,
                size: PulseSize.icon,
                color: colors.mutedForeground,
                semanticLabel: block.checked
                    ? NotesStrings.done
                    : NotesStrings.notDone,
              ),
              Expanded(child: render(block.title)),
              if (date != null) PChip(label: date, icon: LucideIcons.calendar),
            ],
          ),
        );
      },
    );
  }

  String? _date(ActionItem item, LocalDate today) {
    if (item.scheduledStart case final start?) {
      final day = LocalDate.fromDateTime(start.toLocal());
      return '${dayLabel(day, today)} ${timeLabel(start)}';
    }
    final due = item.dueDate;
    return due == null ? null : dayLabel(due, today);
  }
}
