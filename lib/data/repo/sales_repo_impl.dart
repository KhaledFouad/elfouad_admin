import '../../domain/entities/sale.dart';
import '../../domain/repo/sales_repo.dart';
import '../data_source/firestore_sales_ds.dart';

class SalesRepoImpl implements SalesRepo {
  final FirestoreSalesDs ds;
  SalesRepoImpl(this.ds);
  @override
  Future<List<Sale>> getSalesInRange(DateTime s, DateTime e) =>
      ds.fetchRaw(s, e);
}
