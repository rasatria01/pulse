import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/local_date.dart';
import '../tokens.dart';
import '../widgets/p_chip.dart';
import 'planner_format.dart';
import 'planner_strings.dart';

/// A caption over a form control, with an optional error line under it.
class PField extends StatelessWidget {
  const PField({
    super.key,
    required this.label,
    required this.child,
    this.error,
  });

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PulseSpace.s1,
      children: [
        Text(
          label,
          style: PulseText.captionStrong.copyWith(
            color: colors.mutedForeground,
          ),
        ),
        child,
        if (error != null)
          Text(
            error!,
            style: PulseText.caption.copyWith(color: colors.destructive),
          ),
      ],
    );
  }
}

/// One choice out of a few, as a chip row.
class PChoiceField<T> extends StatelessWidget {
  const PChoiceField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => PField(
    label: label,
    child: PChipRow(
      children: [
        for (final (option, text) in options)
          PChip(
            field: label,
            label: text,
            selected: option == value,
            onPressed: () => onChanged(option),
          ),
      ],
    ),
  );
}

/// None, today, tomorrow, or a day picked from a calendar.
class PDateField extends StatefulWidget {
  const PDateField({
    super.key,
    required this.label,
    required this.value,
    required this.today,
    required this.onChanged,
    this.allowNone = true,
  });

  final String label;
  final LocalDate? value;
  final LocalDate today;
  final ValueChanged<LocalDate?> onChanged;
  final bool allowNone;

  @override
  State<PDateField> createState() => _PDateFieldState();
}

class _PDateFieldState extends State<PDateField> {
  var _picking = false;

  void _choose(LocalDate? day) {
    setState(() => _picking = false);
    widget.onChanged(day);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final today = widget.today;
    final tomorrow = today.addDays(1);
    Widget chip(String text, LocalDate? day) => PChip(
      field: widget.label,
      label: text,
      selected: value == day && !_picking,
      onPressed: () => _choose(day),
    );
    return PField(
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PChipRow(
            children: [
              if (widget.allowNone) chip(PlannerStrings.none, null),
              chip(PlannerStrings.today, today),
              chip(PlannerStrings.tomorrow, tomorrow),
              if (value != null && value != today && value != tomorrow)
                chip(dayLabel(value, today), value),
              PChip(
                field: widget.label,
                label: PlannerStrings.pickDate,
                icon: LucideIcons.calendar,
                selected: _picking,
                onPressed: () => setState(() => _picking = !_picking),
              ),
            ],
          ),
          if (_picking)
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ShadCalendar(
                  selected: value == null
                      ? null
                      : DateTime(value.year, value.month, value.day),
                  initialMonth: DateTime(
                    (value ?? today).year,
                    (value ?? today).month,
                  ),
                  weekStartsOn: DateTime.monday,
                  allowDeselection: false,
                  // Two digits at 1.3x text need a touch-sized cell.
                  dayButtonSize: PulseSize.touch,
                  onChanged: (picked) {
                    if (picked != null) {
                      _choose(LocalDate.fromDateTime(picked));
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final _time = RegExp(r'^([01]?\d|2[0-3])[:.]?([0-5]\d)$');

/// Minutes after midnight for "09:00", "9.00" or "0900"; null if not a time.
int? parseTime(String text) {
  final m = _time.firstMatch(text.trim());
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

/// [day] at [minutes] after local midnight, as a UTC instant.
DateTime instantOn(LocalDate day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes).toUtc();

/// The length choices, keeping a stored length that isn't one of them.
List<(int?, String)> durationOptions(int? current) => [
  (null, PlannerStrings.noEnd),
  for (final m in {30, 60, 120, ?current}.toList()..sort()) (m, spanLabel(m)),
];
