import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/budget.dart';

abstract interface class BudgetRepository {
  Stream<List<BudgetStatus>> watchMonth(LocalMonth month);
  Future<Rupiah> totalCaps(LocalMonth month);
  Future<void> setCap(String categoryId, Rupiah cap, LocalMonth from);
}
