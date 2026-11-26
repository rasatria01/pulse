import 'package:intl/intl.dart';

import '../core/local_date.dart';
import 'strings.dart';

/// Dates and times follow id_ID; the words around them stay English.
/// `initializeDateFormatting` runs before the first frame.
const dateLocale = 'id_ID';

String _format(String pattern, DateTime date) =>
    DateFormat(pattern, dateLocale).format(date);

DateTime _date(LocalDate day) => DateTime(day.year, day.month, day.day);

/// "Today", "Tomorrow", "Yesterday", else "26 Nov" (with the year if it is not
/// this one).
String dayLabel(LocalDate day, LocalDate today) =>
    switch (today.daysUntil(day)) {
      0 => MelaStrings.today,
      1 => MelaStrings.tomorrow,
      -1 => MelaStrings.yesterday,
      _ => dateLabel(day, today),
    };

/// "26 Nov", with the year if it is not this one. For ranges.
String dateLabel(LocalDate day, LocalDate today) =>
    _format(day.year == today.year ? 'd MMM' : 'd MMM y', _date(day));

/// A day heading, with the weekday: "Sen, 30 Nov" or "Today · Rab, 25 Nov".
String weekdayLabel(LocalDate day, LocalDate today) {
  final date = _format(
    day.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM y',
    _date(day),
  );
  return today.daysUntil(day).abs() <= 1
      ? '${dayLabel(day, today)} · $date'
      : date;
}

/// Local 24-hour "08:30" of an instant.
String timeLabel(DateTime instant) => _format('HH:mm', instant.toLocal());

/// "25 Nov 2026, 10:00".
String dateTimeLabel(DateTime instant) =>
    _format('d MMM y, HH:mm', instant.toLocal());

/// Month and weekday names for `ShadCalendar`.
String monthYearLabel(DateTime month) => _format('MMMM y', month);
String monthLabel(DateTime month) => _format('MMMM', month);
String weekdayShort(DateTime day) => _format('EEE', day);
String monthShort(DateTime month) => _format('MMM', month);
