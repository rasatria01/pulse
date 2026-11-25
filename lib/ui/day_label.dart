import 'package:intl/intl.dart';

import '../core/local_date.dart';

/// "Today", "Tomorrow", "Yesterday", else "26 Nov" (with the year if it is not
/// this one).
String dayLabel(LocalDate day, LocalDate today) =>
    switch (today.daysUntil(day)) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => DateFormat(
        day.year == today.year ? 'd MMM' : 'd MMM yyyy',
      ).format(DateTime(day.year, day.month, day.day)),
    };

/// 24-hour "08:30".
String timeLabel(DateTime local) => DateFormat('HH:mm').format(local);
