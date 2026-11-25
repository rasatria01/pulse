import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Priority inbox. Returns a sliver.
class InboxSection extends StatelessWidget {
  const InboxSection({super.key});

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PSectionHeader(PulseStrings.priorityInbox),
        EmptyState(icon: LucideIcons.inbox, title: PulseStrings.noInbox),
      ],
    ),
  );
}
