// PRD section 5, date and time words (Indonesian and English).
//
// Every matcher reads lowercase words starting at index i. A word that is
// escaped or already claimed is '', so a phrase can never run across it.
import '../../core/local_date.dart';

typedef DateMatch = ({int words, LocalDate date});

/// [start] and [end] are minutes after midnight.
typedef TimeMatch = ({int words, int start, int? end});

const _relativeDays = {
  'today': 0,
  'tdy': 0,
  'tomorrow': 1,
  'tmr': 1,
  'besok': 1,
  'bsk': 1,
  'lusa': 2,
  'yesterday': -1,
  'kemarin': -1,
  'kmrn': -1,
};

const _weekdays = {
  'mon': DateTime.monday,
  'monday': DateTime.monday,
  'senin': DateTime.monday,
  'tue': DateTime.tuesday,
  'tuesday': DateTime.tuesday,
  'selasa': DateTime.tuesday,
  'wed': DateTime.wednesday,
  'wednesday': DateTime.wednesday,
  'rabu': DateTime.wednesday,
  'thu': DateTime.thursday,
  'thursday': DateTime.thursday,
  'kamis': DateTime.thursday,
  'fri': DateTime.friday,
  'friday': DateTime.friday,
  'jumat': DateTime.friday,
  "jum'at": DateTime.friday,
  'jum’at': DateTime.friday, // phone keyboards type a curly quote
  'sat': DateTime.saturday,
  'saturday': DateTime.saturday,
  'sabtu': DateTime.saturday,
  'sun': DateTime.sunday,
  'sunday': DateTime.sunday,
  'minggu': DateTime.sunday,
  'ahad': DateTime.sunday,
};

const _months = {
  'jan': 1,
  'january': 1,
  'januari': 1,
  'feb': 2,
  'february': 2,
  'februari': 2,
  'mar': 3,
  'march': 3,
  'maret': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'mei': 5,
  'jun': 6,
  'june': 6,
  'juni': 6,
  'jul': 7,
  'july': 7,
  'juli': 7,
  'aug': 8,
  'august': 8,
  'agu': 8,
  'ags': 8,
  'agt': 8,
  'agustus': 8,
  'sep': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'okt': 10,
  'oktober': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
  'des': 12,
  'desember': 12,
};

const _dayParts = {
  'pagi': 8 * 60,
  'siang': 12 * 60,
  'sore': 16 * 60,
  'malam': 19 * 60,
};

final _slashDate = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{4}))?$');
final _dayNumber = RegExp(r'^\d{1,2}$');
final _year = RegExp(r'^[12]\d{3}$');
final _count = RegExp(r'^\d{1,4}$');
final _clock = RegExp(r'^(\d{1,2})(?:([:.])(\d{2}))?(am|pm)?$');

String _at(List<String> w, int i) => i < w.length ? w[i] : '';

DateMatch? matchDate(List<String> w, int i, LocalDate today) {
  final a = w[i], b = _at(w, i + 1), c = _at(w, i + 2);
  DateMatch inDays(int words, int n) => (words: words, date: today.addDays(n));
  DateMatch nextWeek() => inDays(2, 8 - today.weekday);
  // Strictly after today.
  int until(int weekday) => (weekday - today.weekday + 6) % 7 + 1;

  if ((a == 'hari' || a == 'hr') && b == 'ini') return inDays(2, 0);
  if (a == 'next' && b == 'week') return nextWeek();
  if (a == 'minggu' && b == 'depan') return nextWeek();
  if (a == 'hari') {
    final day = _weekdays[b];
    if (day != null) return inDays(2, until(day));
  }
  if (a == 'in' && _count.hasMatch(b) && (c == 'days' || c == 'day')) {
    return inDays(3, int.parse(b));
  }
  if (_count.hasMatch(a) && b == 'hari' && c == 'lagi') {
    return inDays(3, int.parse(a));
  }

  final relative = _relativeDays[a];
  if (relative != null) return inDays(1, relative);
  final weekday = _weekdays[a];
  if (weekday != null) return inDays(1, until(weekday));

  final slash = _slashDate.firstMatch(a);
  if (slash != null) {
    final year = slash[3];
    final date = _calendarDate(
      int.parse(slash[1]!),
      int.parse(slash[2]!),
      year == null ? null : int.parse(year),
      today,
    );
    return date == null ? null : (words: 1, date: date);
  }

  final month = _months[b];
  if (month != null && _dayNumber.hasMatch(a)) {
    final hasYear = _year.hasMatch(c);
    final date = _calendarDate(
      int.parse(a),
      month,
      hasYear ? int.parse(c) : null,
      today,
    );
    return date == null ? null : (words: hasYear ? 3 : 2, date: date);
  }
  return null;
}

/// Null for an impossible date. Without a year, a past date means next year.
LocalDate? _calendarDate(int day, int month, int? year, LocalDate today) {
  LocalDate? valid(int y) {
    final d = LocalDate(y, month, day);
    return d.addDays(0) == d ? d : null;
  }

  if (year != null) return valid(year);
  final thisYear = valid(today.year);
  if (thisYear != null && !thisYear.isBefore(today)) return thisYear;
  return valid(today.year + 1);
}

/// 14:00-15:30, 9am-10am, jam 9-10.
TimeMatch? matchTimeRange(List<String> w, int i) => _match(w, i, range: true);

/// 09:00, 9.30, 9am, jam 9, pukul 14:00, jam 2 siang.
TimeMatch? matchTime(List<String> w, int i) => _match(w, i, range: false);

TimeMatch? _match(List<String> w, int i, {required bool range}) {
  final prefixed = w[i] == 'jam' || w[i] == 'pukul';
  var next = prefixed ? i + 1 : i;
  final parts = range ? _at(w, next).split('-') : [_at(w, next)];
  if (parts.length != (range ? 2 : 1)) return null;
  next++;

  // Day parts adjust only the jam/pukul reading.
  String? part;
  var partWords = 0;
  if (prefixed) {
    if (_at(w, next) == 'nanti' && _at(w, next + 1) == 'malam') {
      part = 'malam';
      partWords = 2;
    } else if (_dayParts.containsKey(_at(w, next))) {
      part = _at(w, next);
      partWords = 1;
    }
  }

  final start = _minutes(parts.first, prefixed: prefixed, part: part);
  if (start == null) return null;
  int? end;
  if (range) {
    end = _minutes(parts.last, prefixed: prefixed, part: part);
    if (end == null) return null;
  }
  return (words: next + partWords - i, start: start, end: end);
}

int? _minutes(String text, {required bool prefixed, String? part}) {
  final m = _clock.firstMatch(text);
  if (m == null) return null;
  final half = m[4];
  // A bare number is a time only after jam/pukul.
  if (!prefixed && m[2] == null && half == null) return null;
  var hour = int.parse(m[1]!);
  final minute = int.parse(m[3] ?? '0');
  if (minute > 59) return null;
  if (half != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (half == 'pm' ? 12 : 0);
  } else {
    if (hour > 23) return null;
    final shift = switch (part) {
      'siang' => hour >= 1 && hour <= 4,
      'sore' => hour >= 3 && hour <= 6,
      'malam' => hour >= 6 && hour <= 11,
      _ => false,
    };
    if (shift) hour += 12;
  }
  return hour * 60 + minute;
}

/// A day part on its own is a default time.
TimeMatch? matchDayPart(List<String> w, int i) {
  if (w[i] == 'nanti' && _at(w, i + 1) == 'malam') {
    return (words: 2, start: _dayParts['malam']!, end: null);
  }
  final start = _dayParts[w[i]];
  return start == null ? null : (words: 1, start: start, end: null);
}
