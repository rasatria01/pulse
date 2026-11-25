import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/local_date.dart';
import '../strings.dart';
import '../widgets/p_button.dart';
import '../widgets/p_sheet.dart';
import 'form_fields.dart';
import 'planner_strings.dart';

typedef Slot = ({DateTime start, DateTime? end});

/// Day, time and length. Pops a [Slot], or null when dismissed.
class ScheduleSheet extends StatefulWidget {
  const ScheduleSheet({super.key, required this.title, required this.today});

  /// The item being scheduled.
  final String title;
  final LocalDate today;

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  final _time = TextEditingController(text: '09:00');
  late var _day = widget.today;
  int? _minutes;

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  void _save() {
    final time = parseTime(_time.text);
    if (time == null) return;
    final start = instantOn(_day, time);
    final minutes = _minutes;
    Navigator.of(context).pop<Slot>((
      start: start,
      end: minutes == null ? null : start.add(Duration(minutes: minutes)),
    ));
  }

  @override
  Widget build(BuildContext context) => PSheet(
    title: PulseStrings.schedule,
    footer: [
      PButton.primary(
        label: PulseStrings.schedule,
        onPressed: parseTime(_time.text) == null ? null : _save,
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(widget.title),
        PDateField(
          label: PlannerStrings.scheduleDate,
          value: _day,
          today: widget.today,
          allowNone: false,
          onChanged: (day) => setState(() => _day = day ?? _day),
        ),
        PField(
          label: PlannerStrings.startTime,
          error: parseTime(_time.text) == null ? PlannerStrings.badTime : null,
          child: ShadInput(
            key: const ValueKey('item-time'),
            controller: _time,
            keyboardType: TextInputType.datetime,
            onChanged: (_) => setState(() {}),
          ),
        ),
        PChoiceField<int?>(
          label: PlannerStrings.duration,
          value: _minutes,
          options: durationOptions(_minutes),
          onChanged: (m) => setState(() => _minutes = m),
        ),
      ],
    ),
  );
}
