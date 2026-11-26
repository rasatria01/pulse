import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/local_date.dart';
import '../../domain/entities/action_item.dart';
import '../widgets/p_button.dart';
import '../widgets/p_sheet.dart';
import '../strings.dart';
import 'form_fields.dart';
import 'planner_format.dart';
import 'planner_strings.dart';

enum ItemSheetAction { save, toggleDone, delete }

/// [values] carries only what the form edits.
typedef ItemSheetResult = ({
  ItemSheetAction action,
  ActionItemInput values,
  List<String> tagSlugs,
});

final _slug = RegExp(r'^[a-z0-9_-]+$');

/// Slugs typed as "#home, admin"; null if one has a character a tag can't take.
List<String>? parseTags(String text) {
  final slugs = [
    for (final word in text.split(RegExp(r'[\s,]+')))
      if (word.replaceFirst('#', '').isNotEmpty)
        word.replaceFirst('#', '').toLowerCase(),
  ];
  return slugs.every(_slug.hasMatch) ? slugs : null;
}

/// Create or edit a task. Pops an [ItemSheetResult], or null when dismissed.
class ItemSheet extends StatefulWidget {
  const ItemSheet({
    super.key,
    required this.today,
    this.item,
    this.tagSlugs = const [],
    this.scheduleOn,
  });

  final LocalDate today;

  /// Null creates a new item.
  final ActionItem? item;
  final List<String> tagSlugs;

  /// Pre-fills the schedule of a new item.
  final LocalDate? scheduleOn;

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  late final _item = widget.item;
  late final _start = _item?.scheduledStart?.toLocal();
  late final _title = TextEditingController(text: _item?.title);
  late final _tags = TextEditingController(
    text: widget.tagSlugs.map((s) => '#$s').join(' '),
  );
  late final _timeText = TextEditingController(
    text: _start == null ? '09:00' : timeLabel(_start),
  );
  late var _priority = _item?.priority ?? Priority.none;
  late var _due = _item?.dueDate;
  late var _day = _start == null
      ? widget.scheduleOn
      : LocalDate.fromDateTime(_start);
  late var _minutes = _item?.scheduledEnd
      ?.difference(_item.scheduledStart!)
      .inMinutes;
  late var _offset = _item?.reminderOffsetMin ?? 0;
  var _tried = false;

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    _timeText.dispose();
    super.dispose();
  }

  void _submit(ItemSheetAction action) {
    final title = _title.text.trim();
    final slugs = parseTags(_tags.text);
    final day = _day;
    final time = day == null ? null : parseTime(_timeText.text);
    if (title.isEmpty || slugs == null || (day != null && time == null)) {
      // Delete needs no valid form.
      if (action != ItemSheetAction.delete) {
        setState(() => _tried = true);
        return;
      }
    }
    final start = day == null || time == null ? null : instantOn(day, time);
    final minutes = _minutes;
    Navigator.of(context).pop<ItemSheetResult>((
      action: action,
      values: ActionItemInput(
        title: title,
        priority: _priority,
        dueDate: _due,
        scheduledStart: start,
        scheduledEnd: start == null || minutes == null
            ? null
            : start.add(Duration(minutes: minutes)),
        reminderOffsetMin: start == null || _offset == 0 ? null : _offset,
      ),
      tagSlugs: slugs ?? const [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final done = item?.status == ActionStatus.done;
    return PSheet(
      title: item == null ? PlannerStrings.newTask : PlannerStrings.editTask,
      footer: [
        if (item != null) ...[
          PButton.ghost(
            label: PlannerStrings.delete,
            icon: LucideIcons.trash2,
            onPressed: () => _submit(ItemSheetAction.delete),
          ),
          PButton.secondary(
            label: done ? PlannerStrings.reopen : PlannerStrings.complete,
            onPressed: () => _submit(ItemSheetAction.toggleDone),
          ),
        ],
        PButton.primary(
          label: MelaStrings.save,
          onPressed: () => _submit(ItemSheetAction.save),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          PField(
            label: PlannerStrings.title,
            error: _tried && _title.text.trim().isEmpty
                ? PlannerStrings.needsTitle
                : null,
            child: ShadInput(
              key: const ValueKey('item-title'),
              controller: _title,
              autofocus: item == null,
              textCapitalization: TextCapitalization.sentences,
              placeholder: const Text(PlannerStrings.titlePlaceholder),
            ),
          ),
          PChoiceField<Priority>(
            label: PlannerStrings.priority,
            value: _priority,
            options: [
              for (final p in Priority.values)
                (p, priorityLabel(p) ?? PlannerStrings.none),
            ],
            onChanged: (p) => setState(() => _priority = p),
          ),
          PDateField(
            label: PlannerStrings.dueDate,
            value: _due,
            today: widget.today,
            onChanged: (day) => setState(() => _due = day),
          ),
          PDateField(
            label: PlannerStrings.scheduleDate,
            value: _day,
            today: widget.today,
            onChanged: (day) => setState(() => _day = day),
          ),
          if (_day != null) ...[
            PField(
              label: PlannerStrings.startTime,
              error: _tried && parseTime(_timeText.text) == null
                  ? PlannerStrings.badTime
                  : null,
              child: ShadInput(
                key: const ValueKey('item-time'),
                controller: _timeText,
                keyboardType: TextInputType.datetime,
              ),
            ),
            PChoiceField<int?>(
              label: PlannerStrings.duration,
              value: _minutes,
              options: durationOptions(_minutes),
              onChanged: (m) => setState(() => _minutes = m),
            ),
            PChoiceField<int>(
              label: PlannerStrings.reminder,
              value: _offset,
              options: [
                for (final m in {0, 10, 30, 60, 1440, _offset}.toList()..sort())
                  (
                    m,
                    m == 0
                        ? PlannerStrings.atStart
                        : PlannerStrings.before(spanLabel(m)),
                  ),
              ],
              onChanged: (m) => setState(() => _offset = m),
            ),
          ],
          PField(
            label: PlannerStrings.tags,
            error: _tried && parseTags(_tags.text) == null
                ? PlannerStrings.badTags
                : null,
            child: ShadInput(
              key: const ValueKey('item-tags'),
              controller: _tags,
              autocorrect: false,
              placeholder: const Text(PlannerStrings.tagsPlaceholder),
            ),
          ),
        ],
      ),
    );
  }
}
