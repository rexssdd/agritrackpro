import 'package:cloud_firestore/cloud_firestore.dart';

num n(dynamic v) => v is num ? v : 0;
DateTime date(dynamic v) =>
    v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

class Product {
  final String id, name, category, unit, description, imageBase64;
  final double price, cost;
  final int stock, reorderLevel;
  final bool active;
  Product(
      {required this.id,
      required this.name,
      required this.category,
      required this.unit,
      required this.price,
      required this.cost,
      required this.stock,
      required this.reorderLevel,
      this.active = true,
      this.description = '',
      this.imageBase64 = ''});
  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Product(
        id: d.id,
        name: m['name'] ?? '',
        category: m['category'] ?? '',
        unit: m['unit'] ?? 'pcs',
        price: n(m['price']).toDouble(),
        cost: n(m['cost']).toDouble(),
        stock: n(m['stock']).toInt(),
        reorderLevel: n(m['reorderLevel']).toInt(),
        active: m['active'] != false,
        description: m['description'] ?? '',
        imageBase64: m['imageBase64'] is String ? m['imageBase64'] : '');
  }
  Map<String, dynamic> toMap() => {
        'description': description,
        'imageBase64': imageBase64,
        'name': name,
        'category': category,
        'unit': unit,
        'price': price,
        'cost': cost,
        'stock': stock,
        'reorderLevel': reorderLevel,
        'active': active,
        'updatedAt': FieldValue.serverTimestamp()
      };
}

class Sale {
  final String id, method, customer, cashierId, paymentReference;
  final double total, cost, amountPaid;
  final DateTime createdAt;
  final List<dynamic> items;
  Sale(this.id, Map<String, dynamic> m)
      : method = m['method'] ?? '',
        paymentReference = m['paymentReference'] ?? '',
        customer = m['customer'] ?? '',
        cashierId = m['cashierId'] ?? '',
        total = n(m['total']).toDouble(),
        cost = n(m['cost']).toDouble(),
        amountPaid = n(m['amountPaid']).toDouble(),
        createdAt = date(m['createdAt']),
        items = m['items'] ?? [];
}

class Expense {
  final String id, description, category;
  final double amount;
  final DateTime createdAt;
  Expense(this.id, Map<String, dynamic> m)
      : description = m['description'] ?? '',
        category = m['category'] ?? '',
        amount = n(m['amount']).toDouble(),
        createdAt = date(m['createdAt']);
}

class CustomerOrder {
  final String id,
      customerId,
      customerEmail,
      address,
      deliveryMode,
      paymentMethod,
      paymentReference,
      status,
      saleId;
  final double total;
  final DateTime createdAt;
  final List<dynamic> items;
  CustomerOrder(this.id, Map<String, dynamic> m)
      : customerId = m['customerId'] ?? '',
        customerEmail = m['customerEmail'] ?? '',
        address = m['address'] ?? '',
        deliveryMode = m['deliveryMode'] ?? '',
        paymentMethod = m['paymentMethod'] ?? '',
        paymentReference = m['paymentReference'] ?? '',
        status = m['status'] ?? 'pending',
        saleId = m['saleId'] ?? '',
        total = n(m['total']).toDouble(),
        createdAt = date(m['createdAt']),
        items = m['items'] ?? [];
}
