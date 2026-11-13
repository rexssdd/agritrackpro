import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/expense_model.dart';

class StoreService {
  StoreService._();
  static final StoreService instance = StoreService._();
  final products = <Product>[
    Product(id: 'P001', name: 'Fertilizer 16-16-16', category: 'Fertilizer', costPrice: 220, sellingPrice: 300, stock: 24),
    Product(id: 'P002', name: 'Insecticide Plus', category: 'Insecticide', costPrice: 180, sellingPrice: 250, stock: 8),
    Product(id: 'P003', name: 'Foliar Spray', category: 'Foliar', costPrice: 125, sellingPrice: 180, stock: 0),
    Product(id: 'P004', name: 'Organic Pesticide', category: 'Pesticide', costPrice: 155, sellingPrice: 220, stock: 15),
  ];
  final sales = <Sale>[];
  final expenses = <Expense>[];

  double get revenue => sales.fold(0, (sum, sale) => sum + sale.total);
  double get costOfGoods => sales.fold(0, (sum, sale) => sum + sale.costOfGoods);
  double get operatingExpenses => expenses.fold(0, (sum, expense) => sum + expense.amount);
  double get estimatedProfit => revenue - costOfGoods - operatingExpenses;

  void recordSale(Product product, int quantity, String paymentMethod) {
    if (quantity <= 0 || quantity > product.stock) {
      throw StateError('Invalid quantity or insufficient stock');
    }
    sales.add(Sale(id: 'S${DateTime.now().microsecondsSinceEpoch}', productName: product.name,
      quantity: quantity, unitPrice: product.sellingPrice, unitCost: product.costPrice,
      paymentMethod: paymentMethod, createdAt: DateTime.now()));
    product.stock -= quantity;
  }
}
