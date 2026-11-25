import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

/// Financial pulse. Returns a sliver.
class PulseSection extends StatelessWidget {
  const PulseSection({super.key});

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PSectionHeader(PulseStrings.financialPulse),
        EmptyState(icon: LucideIcons.wallet, title: PulseStrings.noPulse),
      ],
    ),
  );
}
