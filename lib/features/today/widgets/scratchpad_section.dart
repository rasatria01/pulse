import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../../app/di.dart';
import '../../../core/routes.dart';
import '../../../domain/services/checklist.dart';
import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Today's daily note (PRD F2); a tap opens the editor. Returns a sliver.
class ScratchpadSection extends ConsumerWidget {
  const ScratchpadSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final note = ref.watch(dailyNoteProvider(today)).value;
    final text = hideBlockIds(note?.body ?? '').trim();
    final colors = ShadTheme.of(context).colorScheme;
    void open() => context.push(
      Routes.notePath('${Routes.dailyNotePrefix}${today.toIso()}'),
    );

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PSectionHeader(PulseStrings.scratchpad),
          Semantics(
            container: true,
            button: true,
            child: GestureDetector(
              key: const ValueKey('scratchpad'),
              behavior: HitTestBehavior.opaque,
              onTap: open,
              child: text.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.notebookPen,
                      title: PulseStrings.noScratchpad,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PulseSpace.s4,
                        PulseSpace.s1,
                        PulseSpace.s4,
                        PulseSpace.s4,
                      ),
                      child: Text(
                        text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: PulseText.body.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
