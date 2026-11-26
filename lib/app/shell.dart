import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../features/capture/capture_sheet.dart';
import '../ui/strings.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/widgets.dart';

// In the order of the router's branches.
const _tabs = [
  ('today', MelaStrings.today, LucideIcons.sunMedium),
  ('tasks', MelaStrings.tasks, LucideIcons.listTodo),
  ('calendar', MelaStrings.calendar, LucideIcons.calendar),
  ('notes', MelaStrings.notes, LucideIcons.stickyNote),
  ('finance', MelaStrings.finance, LucideIcons.wallet),
];

/// The five tabs: the current screen, the pinned capture bar and the bottom
/// navigation. In app/ because it joins features together.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    // Only the navigation bar sits on the bottom system inset.
    Widget above(Widget child) => MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: child,
    );
    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          Expanded(child: above(shell)),
          above(PCaptureBar(onOpen: () => showCaptureSheet(context))),
          ColoredBox(
            color: colors.card,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (final (i, (id, label, icon)) in _tabs.indexed)
                    Expanded(
                      child: _Tab(
                        key: ValueKey('tab-$id'),
                        label: label,
                        icon: icon,
                        selected: i == shell.currentIndex,
                        // Tapping the current tab returns to its first screen.
                        onTap: () => shell.goBranch(
                          i,
                          initialLocation: i == shell.currentIndex,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.mutedForeground;
    return PTapTarget(
      label: label,
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MelaSpace.s1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: MelaSize.icon, color: color),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MelaText.micro.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
