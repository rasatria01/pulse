import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/routes.dart';
import '../../domain/entities/note.dart';
import '../../ui/planner/planner_format.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'notes_strings.dart';

/// Today's scratchpad, then every other note: pinned first, newest first.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(noteSummariesProvider);
    final today = ref.watch(todayProvider);
    void open(String id) => context.push(Routes.notePath(id));
    void create() => open(Routes.newNoteId);

    NoteSummary? daily;
    final rest = <NoteSummary>[];
    for (final note in notes.value ?? const <NoteSummary>[]) {
      if (note.dailyDate == today) {
        daily = note;
      } else {
        rest.add(note);
      }
    }
    // A scratchpad is titled by its day; its first line joins the preview.
    String words(NoteSummary n) => '${n.title} ${n.preview}'.trim();

    return PScreen(
      title: PulseStrings.notes,
      actions: [
        PButton.ghost(
          icon: LucideIcons.plus,
          semanticLabel: NotesStrings.newNote,
          onPressed: create,
        ),
      ],
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _NoteRow(
              icon: LucideIcons.notebookPen,
              title: NotesStrings.todayScratchpad,
              preview: daily == null ? PulseStrings.noScratchpad : words(daily),
              onTap: () => open('${Routes.dailyNotePrefix}${today.toIso()}'),
            ),
          ),
          if (notes.hasValue && rest.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: LucideIcons.stickyNote,
                title: PulseStrings.noNotes,
                actionLabel: NotesStrings.newNote,
                actionIcon: LucideIcons.plus,
                onAction: create,
              ),
            ),
          SliverList.builder(
            itemCount: rest.length,
            itemBuilder: (context, i) {
              final note = rest[i];
              final date = note.dailyDate;
              return _NoteRow(
                key: ValueKey(note.id),
                icon: date != null
                    ? LucideIcons.notebookPen
                    : note.isPinned
                    ? LucideIcons.pin
                    : LucideIcons.stickyNote,
                title: date != null
                    ? NotesStrings.scratchpad(dayLabel(date, today))
                    : note.title.isEmpty
                    ? NotesStrings.untitled
                    : note.title,
                preview: date != null ? words(note) : note.preview,
                onTap: () => open(note.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    super.key,
    required this.icon,
    required this.title,
    required this.preview,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PulseSpace.s4,
            vertical: PulseSpace.s2,
          ),
          child: Row(
            spacing: PulseSpace.s3,
            children: [
              PIconTile(icon: icon),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseText.bodyStrong.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PulseText.caption.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
