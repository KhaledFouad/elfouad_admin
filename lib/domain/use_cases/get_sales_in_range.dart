import '../entities/sale.dart';
import '../repo/sales_repo.dart';

class GetSalesInRange {
  final SalesRepo repo;
  GetSalesInRange(this.repo);

  Future<List<Sale>> call(DateTime startUtc, DateTime endUtc) => repo.getSalesInRange(startUtc, endUtc);
}