import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Today's schedule and Due lane. Returns a sliver.
class TimelineSection extends StatelessWidget {
  const TimelineSection({super.key});

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PSectionHeader(PulseStrings.timeline),
        EmptyState(icon: LucideIcons.clock, title: PulseStrings.noTimeline),
      ],
    ),
  );
}
