import 'entities.dart';

class ProductPerformance {
  const ProductPerformance({
    required this.productId,
    required this.name,
    required this.category,
    required this.unit,
    required this.stock,
    required this.active,
    required this.unitsSold,
    required this.revenueCentavos,
    required this.transactions,
    this.lastSoldAt,
    this.imageBase64 = '',
  });

  final String productId;
  final String name;
  final String category;
  final String unit;
  final int stock;
  final bool active;
  final int unitsSold;
  final int revenueCentavos;
  final int transactions;
  final DateTime? lastSoldAt;
  final String imageBase64;

  double get revenue => revenueCentavos / 100;
}

class ProductPerformanceReport {
  const ProductPerformanceReport({
    required this.products,
    required this.unitsSold,
    required this.revenueCentavos,
  });

  final List<ProductPerformance> products;
  final int unitsSold;
  final int revenueCentavos;

  int get sellingCount =>
      products.where((product) => product.unitsSold > 0).length;
  int get unsoldCount =>
      products.where((product) => product.unitsSold == 0).length;
  double get revenue => revenueCentavos / 100;

  List<ProductPerformance> get topSellers {
    final sold = products.where((product) => product.unitsSold > 0).toList()
      ..sort((a, b) {
        final byUnits = b.unitsSold.compareTo(a.unitsSold);
        return byUnits != 0
            ? byUnits
            : b.revenueCentavos.compareTo(a.revenueCentavos);
      });
    return sold.take(5).toList();
  }

  List<ProductPerformance> get slowMovers {
    final highest = products.fold<int>(
        0, (max, product) => product.unitsSold > max ? product.unitsSold : max);
    final slow = products
        .where((product) =>
            product.active &&
            (product.unitsSold == 0 || product.unitsSold < highest))
        .toList()
      ..sort((a, b) {
        final byUnits = a.unitsSold.compareTo(b.unitsSold);
        return byUnits != 0
            ? byUnits
            : a.revenueCentavos.compareTo(b.revenueCentavos);
      });
    return slow.take(5).toList();
  }

  factory ProductPerformanceReport.fromRecords(
      List<Product> products, List<Sale> sales) {
    final byId = <String, _ProductTotals>{
      for (final product in products) product.id: _ProductTotals(product),
    };
    for (final sale in sales) {
      for (final raw in sale.items) {
        if (raw is! Map) continue;
        final id = raw['productId'];
        final quantity = raw['quantity'];
        if (id is! String ||
            id.isEmpty ||
            quantity is! num ||
            quantity <= 0 ||
            quantity != quantity.roundToDouble()) {
          continue;
        }
        final totals = byId.putIfAbsent(
            id,
            () => _ProductTotals(Product(
                id: id,
                name: raw['name'] is String ? raw['name'] : id,
                category: 'Archived',
                unit: raw['unit'] is String ? raw['unit'] : 'pcs',
                price: 0,
                cost: 0,
                stock: 0,
                reorderLevel: 0,
                active: false)));
        totals.unitsSold += quantity.toInt();
        final subtotal = raw['subtotal'] is num
            ? (raw['subtotal'] as num).toDouble()
            : raw['price'] is num
                ? (raw['price'] as num).toDouble() * quantity
                : 0.0;
        if (subtotal.isFinite && subtotal >= 0) {
          totals.revenueCentavos += (subtotal * 100).round();
        }
        totals.transactions++;
        if (totals.lastSoldAt == null ||
            sale.createdAt.isAfter(totals.lastSoldAt!)) {
          totals.lastSoldAt = sale.createdAt;
        }
      }
    }
    final entries = byId.values
        .where((totals) => totals.product.active || totals.unitsSold > 0)
        .map((totals) => ProductPerformance(
              productId: totals.product.id,
              name: totals.product.name,
              category: totals.product.category,
              unit: totals.product.unit,
              stock: totals.product.stock,
              active: totals.product.active,
              imageBase64: totals.product.imageBase64,
              unitsSold: totals.unitsSold,
              revenueCentavos: totals.revenueCentavos,
              transactions: totals.transactions,
              lastSoldAt: totals.lastSoldAt,
            ))
        .toList();
    return ProductPerformanceReport(
      products: entries,
      unitsSold: entries.fold(0, (sum, product) => sum + product.unitsSold),
      revenueCentavos:
          entries.fold(0, (sum, product) => sum + product.revenueCentavos),
    );
  }
}

class _ProductTotals {
  _ProductTotals(this.product);
  final Product product;
  int unitsSold = 0;
  int revenueCentavos = 0;
  int transactions = 0;
  DateTime? lastSoldAt;
}
