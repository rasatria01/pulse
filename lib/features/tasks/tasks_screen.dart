import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../domain/entities/action_item.dart';
import '../../ui/planner/planner_strings.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'tasks_strings.dart';
import 'widgets/task_row.dart';

/// Unscheduled items (PRD F4): open first, then done.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(tasksProvider(ActionStatus.open));
    final done = ref.watch(tasksProvider(ActionStatus.done));
    final tags = ref.watch(plannerTagsProvider).value ?? const [];
    final today = ref.watch(todayProvider);
    void add() => PlannerFlows.of(context).create();

    Widget list(List<ActionItem> items) => SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return TaskRow(
          key: ValueKey(item.id),
          item: item,
          tags: tags,
          today: today,
          onToggle: () => PlannerFlows.of(context).toggle(item),
          onOpen: () => PlannerFlows.of(context).open(item),
        );
      },
    );

    final Widget body;
    if (open.hasError || done.hasError) {
      body = const EmptyState(
        icon: LucideIcons.circleAlert,
        title: TasksStrings.loadFailed,
      );
    } else if (!open.hasValue || !done.hasValue) {
      body = const SizedBox.shrink();
    } else if (open.requireValue.isEmpty && done.requireValue.isEmpty) {
      body = SingleChildScrollView(
        child: EmptyState(
          icon: LucideIcons.listTodo,
          title: PulseStrings.noTasks,
          body: TasksStrings.emptyBody,
          actionLabel: PlannerStrings.addTask,
          actionIcon: LucideIcons.plus,
          onAction: add,
        ),
      );
    } else {
      body = CustomScrollView(
        slivers: [
          list(open.requireValue),
          if (done.requireValue.isNotEmpty) ...[
            const SliverToBoxAdapter(child: PSectionHeader(TasksStrings.done)),
            list(done.requireValue),
          ],
        ],
      );
    }

    return PScreen(
      title: PulseStrings.tasks,
      actions: [
        PButton.ghost(
          icon: LucideIcons.plus,
          semanticLabel: PlannerStrings.addTask,
          onPressed: add,
        ),
      ],
      child: body,
    );
  }
}
