import '../entities/sale.dart';

abstract class SalesRepo {
  Future<List<Sale>> getSalesInRange(DateTime s, DateTime e);
}
