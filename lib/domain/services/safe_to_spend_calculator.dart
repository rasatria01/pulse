import '../../core/rupiah.dart';
import 'safe_to_spend.dart';

/// PRD 9.4: S = floor((B - P - C) / D), never below 0.
final class DefaultSafeToSpendCalculator implements SafeToSpendCalculator {
  const DefaultSafeToSpendCalculator();

  @override
  SafeToSpend? compute({
    required Rupiah monthCaps,
    required Rupiah spentBeforeToday,
    required Rupiah committed,
    required int daysLeft, // includes today, so at least 1
    required Rupiah spentToday,
  }) {
    // A cap of 0 means "no cap", so a zero total is "no budgets set".
    if (!monthCaps.isPositive) return null;
    if (daysLeft < 1) {
      throw ArgumentError.value(daysLeft, 'daysLeft', 'must include today');
    }
    final left = monthCaps - spentBeforeToday - committed;
    final perDay = Rupiah(left.isPositive ? left.value ~/ daysLeft : 0);
    return SafeToSpend(
      perDay: perDay,
      spentToday: spentToday,
      remaining: perDay - spentToday,
    );
  }
}
