import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => PScreen(
    title: PulseStrings.settings,
    onBack: context.pop,
    child: const EmptyState(
      icon: LucideIcons.settings,
      title: PulseStrings.settingsEmpty,
    ),
  );
}
