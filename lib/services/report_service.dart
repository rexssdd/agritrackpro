import '../models/entities.dart';
import 'store_repository.dart';

abstract class ReportService {
  Stream<List<Product>> watchProducts();
  Stream<List<Sale>> watchSales(DateTime from, DateTime until);
}

class FirebaseReportService implements ReportService {
  FirebaseReportService(this.repository);
  final StoreRepository repository;

  @override
  Stream<List<Product>> watchProducts() => repository.watchProducts();

  @override
  Stream<List<Sale>> watchSales(DateTime from, DateTime until) =>
      repository.watchSalesForPeriod(from, until);
}
