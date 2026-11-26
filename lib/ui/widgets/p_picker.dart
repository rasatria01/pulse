// The pickers behind a chip: a sheet of options, and a date with a time.
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../day_label.dart';
import '../strings.dart';
import '../tokens.dart';
import 'p_button.dart';
import 'p_chip.dart';
import 'p_sheet.dart';

typedef POption<T> = ({T value, String label, int? dotColor});

/// Completes with the tapped value, or null if dismissed.
Future<T?> showPOptions<T extends Object>(
  BuildContext context, {
  required String title,
  required List<POption<T>> options,
  T? selected,
  String? empty,
}) => showPSheet<T>(
  context: context,
  builder: (context) => PSheet(
    title: title,
    child: options.isEmpty
        ? Text(empty ?? '')
        : Wrap(
            spacing: MelaSpace.s2,
            children: [
              for (final option in options)
                PChip(
                  label: option.label,
                  dotColor: option.dotColor,
                  selected: option.value == selected,
                  onPressed: () => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
  ),
);

/// A local date and time, or null if dismissed.
Future<DateTime?> showPDateTime(
  BuildContext context, {
  required String title,
  required String timeFieldLabel,
  required String timeError,
  required DateTime initial,
}) => showPSheet<DateTime>(
  context: context,
  builder: (context) => _DateTimeSheet(
    title: title,
    timeFieldLabel: timeFieldLabel,
    timeError: timeError,
    initial: initial,
  ),
);

class _DateTimeSheet extends StatefulWidget {
  const _DateTimeSheet({
    required this.title,
    required this.timeFieldLabel,
    required this.timeError,
    required this.initial,
  });

  final String title, timeFieldLabel, timeError;
  final DateTime initial;

  @override
  State<_DateTimeSheet> createState() => _DateTimeSheetState();
}

class _DateTimeSheetState extends State<_DateTimeSheet> {
  late DateTime _day = widget.initial;
  late final _time = TextEditingController(text: timeLabel(widget.initial));
  bool _invalid = false;

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  void _save() {
    final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(_time.text.trim());
    final hour = m == null ? 24 : int.parse(m[1]!);
    final minute = m == null ? 60 : int.parse(m[2]!);
    if (hour > 23 || minute > 59) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context)
        .pop(DateTime(_day.year, _day.month, _day.day, hour, minute));
  }

  @override
  Widget build(BuildContext context) => PSheet(
    title: widget.title,
    footer: [PButton.primary(label: MelaStrings.save, onPressed: _save)],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: MelaSpace.s3,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ShadCalendar(
            selected: _day,
            initialMonth: _day,
            weekStartsOn: DateTime.monday,
            allowDeselection: false,
            onChanged: (day) {
              if (day != null) setState(() => _day = day);
            },
          ),
        ),
        Semantics(
          label: widget.timeFieldLabel,
          child: ShadInput(
            controller: _time,
            placeholder: Text(widget.timeFieldLabel),
            keyboardType: TextInputType.datetime,
            onSubmitted: (_) => _save(),
          ),
        ),
        if (_invalid)
          Text(
            widget.timeError,
            style: MelaText.caption.copyWith(
              color: ShadTheme.of(context).colorScheme.destructive,
            ),
          ),
      ],
    ),
  );
}
