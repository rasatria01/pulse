import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => const PScreen(
    title: PulseStrings.calendar,
    child: EmptyState(icon: LucideIcons.calendar, title: PulseStrings.noEvents),
  );
}
