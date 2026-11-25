import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../core/routes.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'widgets/inbox_section.dart';
import 'widgets/needs_confirmation_section.dart';
import 'widgets/pulse_section.dart';
import 'widgets/scratchpad_section.dart';
import 'widgets/timeline_section.dart';

/// PRD F2. Each section is a sliver in its own file, so long lists stay lazy.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => PScreen(
    title: PulseStrings.today,
    actions: [
      PButton.ghost(
        icon: LucideIcons.search,
        semanticLabel: PulseStrings.search,
        onPressed: () => context.push(Routes.search),
      ),
      PButton.ghost(
        icon: LucideIcons.settings,
        semanticLabel: PulseStrings.settings,
        onPressed: () => context.push(Routes.settings),
      ),
    ],
    child: const CustomScrollView(
      slivers: [
        PulseSection(),
        NeedsConfirmationSection(),
        TimelineSection(),
        InboxSection(),
        ScratchpadSection(),
      ],
    ),
  );
}
