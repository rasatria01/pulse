import '../../core/local_date.dart';

/// The dates budget period [month] covers, both inclusive. It starts on
/// budget_month_start_day of that month and ends the day before the next start.
(LocalDate, LocalDate) budgetPeriod(LocalMonth month, String? startDaySetting) {
  final parsed = int.tryParse(startDaySetting ?? '') ?? 1;
  final startDay = parsed < 1 || parsed > 31 ? 1 : parsed;
  return (month.day(startDay), month.addMonths(1).day(startDay).addDays(-1));
}
