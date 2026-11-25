import 'package:flutter/widgets.dart';

/// Pending occurrences and unrecorded bills. Returns a sliver; PRD F2 hides the
/// section when it is empty.
class NeedsConfirmationSection extends StatelessWidget {
  const NeedsConfirmationSection({super.key});

  @override
  Widget build(BuildContext context) =>
      const SliverToBoxAdapter(child: SizedBox.shrink());
}
