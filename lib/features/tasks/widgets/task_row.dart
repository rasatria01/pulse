import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../../core/local_date.dart';
import '../../../domain/entities/action_item.dart';
import '../../../domain/entities/tag.dart';
import '../../../ui/planner/planner_format.dart';
import '../../../ui/planner/planner_strings.dart';
import '../../../ui/strings.dart';
import '../../../ui/theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/widgets.dart';

/// One task: checkbox to complete or reopen, tap to edit.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.item,
    required this.tags,
    required this.today,
    required this.onToggle,
    required this.onOpen,
  });

  final ActionItem item;
  final List<Tag> tags;
  final LocalDate today;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final done = item.status == ActionStatus.done;
    final due = item.dueDate;
    final late = !done && due != null && due.isBefore(today);
    final dueWords = due == null
        ? null
        : late
        ? PlannerStrings.overdueBy(due.daysUntil(today))
        : PlannerStrings.due(dayLabel(due, today));
    final rest = [
      ?priorityLabel(item.priority),
      ?tagLine(item, tags),
    ].join(' · ');
    final caption = PulseText.caption.copyWith(color: colors.mutedForeground);

    return Padding(
      padding: const EdgeInsets.only(left: PulseSpace.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PTapTarget(
            label: PulseStrings.complete(item.title),
            checked: done,
            onTap: onToggle,
            child: ShadCheckbox(
              value: done,
              onChanged: (_) => onToggle(),
              size: 22,
              color: colors.primary,
              uncheckedColor: colors.background.withValues(alpha: 0),
              duration: reduceMotion(context) ? Duration.zero : null,
              decoration: ShadDecoration(
                border: ShadBorder.all(
                  width: 2,
                  color: done ? colors.primary : colors.input,
                  radius: BorderRadius.circular(PulseRadius.sm),
                ),
              ),
              icon: Icon(
                LucideIcons.check,
                size: 14,
                color: colors.primaryForeground,
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    PulseSpace.s3,
                    PulseSpace.s4,
                    PulseSpace.s3,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PulseSpace.s3,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: PulseText.bodyStrong.copyWith(
                                color: done
                                    ? colors.inkSubtle
                                    : colors.foreground,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (dueWords != null)
                              Text(
                                dueWords,
                                style: late
                                    ? PulseText.captionStrong.copyWith(
                                        color: colors.destructive,
                                      )
                                    : caption,
                              ),
                            if (rest.isNotEmpty) Text(rest, style: caption),
                          ],
                        ),
                      ),
                      if (item.linkedAmount != null)
                        TrailingAmount(child: AmountText(item.linkedAmount!)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
