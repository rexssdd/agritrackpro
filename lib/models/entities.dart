import 'package:cloud_firestore/cloud_firestore.dart';

num n(dynamic v) => v is num ? v : 0;
DateTime date(dynamic v) => v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

class Product {
  final String id, name, category, unit;
  final double price, cost;
  final int stock, reorderLevel;
  final bool active;
  Product({required this.id, required this.name, required this.category, required this.unit, required this.price, required this.cost, required this.stock, required this.reorderLevel, this.active=true});
  factory Product.fromDoc(DocumentSnapshot<Map<String,dynamic>> d) { final m=d.data()!; return Product(id:d.id,name:m['name']??'',category:m['category']??'',unit:m['unit']??'pcs',price:n(m['price']).toDouble(),cost:n(m['cost']).toDouble(),stock:n(m['stock']).toInt(),reorderLevel:n(m['reorderLevel']).toInt(),active:m['active']!=false); }
  Map<String,dynamic> toMap()=>{'name':name,'category':category,'unit':unit,'price':price,'cost':cost,'stock':stock,'reorderLevel':reorderLevel,'active':active,'updatedAt':FieldValue.serverTimestamp()};
}
class Sale {
  final String id, method, customer, cashierId;
  final double total, cost, amountPaid;
  final DateTime createdAt;
  final List<dynamic> items;
  Sale(this.id,Map<String,dynamic> m):method=m['method']??'',customer=m['customer']??'',cashierId=m['cashierId']??'',total=n(m['total']).toDouble(),cost=n(m['cost']).toDouble(),amountPaid=n(m['amountPaid']).toDouble(),createdAt=date(m['createdAt']),items=m['items']??[];
}
class Expense {
  final String id, description, category;
  final double amount;
  final DateTime createdAt;
  Expense(this.id,Map<String,dynamic> m):description=m['description']??'',category=m['category']??'',amount=n(m['amount']).toDouble(),createdAt=date(m['createdAt']);
}
