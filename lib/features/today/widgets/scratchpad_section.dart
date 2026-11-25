import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Placeholder for today's daily note (M4). Returns a sliver.
class ScratchpadSection extends StatelessWidget {
  const ScratchpadSection({super.key});

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PSectionHeader(PulseStrings.scratchpad),
        EmptyState(
          icon: LucideIcons.notebookPen,
          title: PulseStrings.noScratchpad,
        ),
      ],
    ),
  );
}
