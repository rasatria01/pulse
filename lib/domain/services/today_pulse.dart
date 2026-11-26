import '../../core/rupiah.dart';
import '../entities/wallet.dart';
import 'safe_to_spend.dart';

/// The numbers on Today's financial pulse card.
final class TodayPulse {
  const TodayPulse({
    required this.liquid,
    required this.todaySpend,
    required this.wallets,
    this.safeToSpend,
  });

  /// Wallets included in the total and not archived.
  final Rupiah liquid;

  /// OUTCOME with occurred_on = today; transfers excluded.
  final Rupiah todaySpend;

  /// Not archived, in display order.
  final List<WalletBalance> wallets;

  /// Null when no budgets are set.
  final SafeToSpend? safeToSpend;
}
