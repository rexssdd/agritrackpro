import 'package:agritrack_pro/models/entities.dart';
import 'package:agritrack_pro/models/product_performance_model.dart';
import 'package:agritrack_pro/services/report_service.dart';
import 'package:agritrack_pro/viewmodels/owner_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Product product(String id, {bool active = true}) => Product(
      id: id,
      name: id,
      category: 'Fertilizer',
      unit: 'sacks',
      price: 100,
      cost: 60,
      stock: 8,
      reorderLevel: 10,
      active: active,
    );

Sale sale(String id, DateTime at, List<Map<String, dynamic>> items) =>
    Sale(id, {
      'createdAt': Timestamp.fromDate(at),
      'items': items,
      'total': items.fold<double>(
          0, (total, item) => total + (item['subtotal'] as num)),
    });

Map<String, dynamic> item(String id, int count, double subtotal) => {
      'productId': id,
      'name': id,
      'quantity': count,
      'subtotal': subtotal,
      'unit': 'sacks',
    };

class FakeReportService implements ReportService {
  FakeReportService(this.products, this.sales);
  final List<Product> products;
  final List<Sale> sales;
  DateTime? from;
  DateTime? until;

  @override
  Stream<List<Product>> watchProducts() => Stream.value(products);

  @override
  Stream<List<Sale>> watchSales(DateTime from, DateTime until) {
    this.from = from;
    this.until = until;
    return Stream.value(sales
        .where((sale) =>
            !sale.createdAt.isBefore(from) && sale.createdAt.isBefore(until))
        .toList());
  }
}

void main() {
  test('ranks sold products and keeps active unsold products visible', () {
    final at = DateTime(2026, 11, 18);
    final report = ProductPerformanceReport.fromRecords(
      [
        product('urea'),
        product('foliar'),
        product('genesis'),
        product('old', active: false)
      ],
      [
        sale('a', at, [item('urea', 2, 190.25), item('foliar', 1, 99.75)]),
        sale('b', at, [item('urea', 3, 300), item('old', 1, 25)]),
      ],
    );

    expect(report.unitsSold, 7);
    expect(report.revenueCentavos, 61500);
    expect(
        report.topSellers.map((p) => p.productId), ['urea', 'foliar', 'old']);
    expect(report.topSellers.first.transactions, 2);
    expect(report.topSellers.first.revenueCentavos, 49025);
    expect(report.slowMovers.map((p) => p.productId), ['genesis', 'foliar']);
    expect(report.unsoldCount, 1);
  });

  test(
      'period selection recalculates from completed sales in the selected window',
      () async {
    final service = FakeReportService([
      product('urea')
    ], [
      sale('old', DateTime(2026, 11, 10), [item('urea', 4, 400)]),
      sale('today', DateTime(2026, 11, 18, 9), [item('urea', 1, 100)]),
    ]);
    final model =
        OwnerViewModel(service, clock: () => DateTime(2026, 11, 18, 12));
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(model.report?.unitsSold, 5);

    model.selectPeriod(PerformancePeriod.today);
    await Future<void>.delayed(Duration.zero);
    expect(service.from, DateTime(2026, 11, 18));
    expect(service.until, DateTime(2026, 11, 19));
    expect(model.report?.unitsSold, 1);
  });
}
