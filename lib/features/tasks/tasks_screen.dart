import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) => const PScreen(
    title: PulseStrings.tasks,
    child: EmptyState(icon: LucideIcons.listTodo, title: PulseStrings.noTasks),
  );
}
