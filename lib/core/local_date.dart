String _pad(int n, int width) => n.toString().padLeft(width, '0');

/// A calendar date with no time and no zone.
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  /// The calendar fields of [d], in whatever zone [d] is already in.
  LocalDate.fromDateTime(DateTime d) : this(d.year, d.month, d.day);

  /// Parses 'YYYY-MM-DD'. Rejects impossible dates such as 2026-02-30.
  factory LocalDate.parse(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (m != null) {
      final date = LocalDate(
        int.parse(m[1]!),
        int.parse(m[2]!),
        int.parse(m[3]!),
      );
      if (date.addDays(0) == date) return date;
    }
    throw FormatException('Not a YYYY-MM-DD date', iso);
  }

  final int year, month, day;

  String toIso() => '${_pad(year, 4)}-${_pad(month, 2)}-${_pad(day, 2)}';

  // UTC arithmetic: no DST gaps can shift the calendar date.
  LocalDate addDays(int n) =>
      LocalDate.fromDateTime(DateTime.utc(year, month, day + n));

  LocalMonth get monthOf => LocalMonth(year, month);

  /// Local 00:00 as a UTC instant, in the device timezone (D18).
  // ponytail: the PRD signature takes a tz name, but core/ may only import
  // dart:*, which has no timezone database. Device zone is what D18 asks for.
  DateTime startUtc() => DateTime(year, month, day).toUtc();

  @override
  int compareTo(LocalDate other) => toIso().compareTo(other.toIso());

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// A calendar month, stored as 'YYYY-MM'.
final class LocalMonth implements Comparable<LocalMonth> {
  const LocalMonth(this.year, this.month);

  factory LocalMonth.parse(String iso) => LocalDate.parse('$iso-01').monthOf;

  final int year, month;

  String toIso() => '${_pad(year, 4)}-${_pad(month, 2)}';

  LocalDate get firstDay => LocalDate(year, month, 1);
  LocalDate get lastDay =>
      LocalDate.fromDateTime(DateTime.utc(year, month + 1, 0));

  @override
  int compareTo(LocalMonth other) => toIso().compareTo(other.toIso());

  @override
  bool operator ==(Object other) =>
      other is LocalMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => toIso();
}
