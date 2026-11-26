import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';
import 'amount_text.dart';
import 'common.dart';

/// Why an item is in the inbox; the inbox orders them this way.
enum InboxReason { overdue, high, today }

/// One open item in the priority inbox. Swipe right or tap the checkbox to
/// complete; swipe left or long-press to schedule.
class PInboxItem extends StatelessWidget {
  const PInboxItem({
    super.key,
    required this.title,
    required this.reason,
    required this.onComplete,
    this.onSchedule,
    this.onPressed,
    this.dueLabel,
    this.meta,
    this.amount,
    this.done = false,
  });

  final String title;
  final InboxReason reason;

  /// Called with the new checkbox state.
  final ValueChanged<bool> onComplete;
  final VoidCallback? onSchedule;
  final VoidCallback? onPressed;

  /// The overdue wording, such as "Overdue · 2 days".
  final String? dueLabel;

  /// Tags.
  final String? meta;

  /// linked_amount, shown as an expense.
  final Rupiah? amount;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final still = reduceMotion(context);
    final (word, icon, color) = switch (reason) {
      InboxReason.overdue => (
        dueLabel ?? PulseStrings.overdue,
        LucideIcons.circleAlert,
        colors.destructive,
      ),
      InboxReason.high => (
        PulseStrings.highPriority,
        LucideIcons.flag,
        colors.foreground,
      ),
      InboxReason.today => (PulseStrings.dueToday, null, colors.foreground),
    };

    final checkbox = PTapTarget(
      label: PulseStrings.complete(title),
      checked: done,
      onTap: () => onComplete(!done),
      child: ShadCheckbox(
        value: done,
        onChanged: onComplete,
        size: 22,
        color: colors.primary,
        uncheckedColor: colors.background.withValues(alpha: 0),
        duration: still ? Duration.zero : null,
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
    );

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PulseText.bodyStrong.copyWith(
            color: done ? colors.inkSubtle : colors.foreground,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        Text.rich(
          TextSpan(
            style: PulseText.caption.copyWith(color: colors.mutedForeground),
            children: [
              if (icon != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: PulseSpace.s1),
                    child: Icon(icon, size: 14, color: color),
                  ),
                ),
              TextSpan(
                text: word,
                style: PulseText.captionStrong.copyWith(color: color),
              ),
              if (meta != null) TextSpan(text: ' · $meta'),
            ],
          ),
        ),
      ],
    );

    final row = ColoredBox(
      color: colors.card,
      child: Padding(
        padding: const EdgeInsets.only(left: PulseSpace.s1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            checkbox,
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPressed,
                onLongPress: onSchedule,
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
                      Expanded(child: text),
                      if (amount != null)
                        TrailingAmount(child: AmountText(amount!)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget swipeBackground(IconData icon, Alignment alignment) => Container(
      color: colors.muted,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: PulseSpace.s4),
      child: Icon(icon, size: PulseSize.icon, color: colors.foreground),
    );

    return Dismissible(
      key: const ValueKey('p-inbox-swipe'),
      direction: onSchedule == null
          ? (done ? DismissDirection.none : DismissDirection.startToEnd)
          : (done ? DismissDirection.endToStart : DismissDirection.horizontal),
      movementDuration: still
          ? Duration.zero
          : const Duration(milliseconds: 200),
      background: swipeBackground(LucideIcons.check, Alignment.centerLeft),
      secondaryBackground: swipeBackground(
        LucideIcons.calendar,
        Alignment.centerRight,
      ),
      // The row never leaves the list by itself: the caller's data decides.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onComplete(true);
        } else {
          onSchedule?.call();
        }
        return false;
      },
      child: row,
    );
  }
}
