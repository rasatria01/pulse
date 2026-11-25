import '../../core/rupiah.dart';
import '../entities/wallet.dart';

/// The numbers on Today's financial pulse card.
final class TodayPulse {
  const TodayPulse({
    required this.liquid,
    required this.todaySpend,
    required this.wallets,
  });

  /// Wallets included in the total and not archived.
  final Rupiah liquid;

  /// OUTCOME with occurred_on = today; transfers excluded.
  final Rupiah todaySpend;

  /// Not archived, in display order.
  final List<WalletBalance> wallets;
}
