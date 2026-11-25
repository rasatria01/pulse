import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/budget.dart';

/// A LocalMonth is a budget period. Implementations apply
/// budget_month_start_day (default 1 = calendar month), here and in
/// TransactionRepository.watchOutcomeByCategory.
abstract interface class BudgetRepository {
  Stream<List<BudgetStatus>> watchMonth(LocalMonth month);
  Future<Rupiah> totalCaps(LocalMonth month);
  Future<void> setCap(String categoryId, Rupiah cap, LocalMonth from);
}
