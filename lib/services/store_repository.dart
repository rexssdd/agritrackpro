import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/entities.dart';

class CartLine {
  final Product product;
  int quantity;
  CartLine(this.product, [this.quantity = 1]);
}

class StoreRepository {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  String role = 'staff';
  String get uid => auth.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get products =>
      db.collection('products');
  CollectionReference<Map<String, dynamic>> get sales => db.collection('sales');
  CollectionReference<Map<String, dynamic>> get expenses =>
      db.collection('expenses');
  String newRequestId() => products.doc().id;

  Future<Map<String, dynamic>> operate(String action, Map<String, dynamic> data,
      {String? requestId}) async {
    final response = await FirebaseFunctions.instance
        .httpsCallable('storeOperation')
        .call<dynamic>({
      ...data,
      'action': action,
      'requestId': requestId ?? newRequestId(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Stream<List<Product>> watchProducts() =>
      (role == 'owner' ? products : db.collection('catalog'))
          .orderBy('name')
          .snapshots()
          .map((s) => s.docs.map(Product.fromDoc).toList());
  Stream<List<Sale>> watchSales() => sales
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Sale(d.id, d.data())).toList());
  Query<Map<String, dynamic>> inPeriod(
          CollectionReference<Map<String, dynamic>> collection,
          DateTime from,
          DateTime until) =>
      collection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('createdAt', isLessThan: Timestamp.fromDate(until))
          .orderBy('createdAt', descending: true);
  Stream<List<Sale>> watchSalesForPeriod(DateTime from, DateTime until) =>
      inPeriod(sales, from, until)
          .snapshots()
          .map((s) => s.docs.map((d) => Sale(d.id, d.data())).toList());
  Stream<List<Expense>> watchExpensesForPeriod(DateTime from, DateTime until) =>
      inPeriod(expenses, from, until)
          .snapshots()
          .map((s) => s.docs.map((d) => Expense(d.id, d.data())).toList());
  Stream<List<Sale>> watchReceipts() {
    Query<Map<String, dynamic>> query = db.collection('receipts');
    if (role != 'owner') query = query.where('cashierId', isEqualTo: uid);
    return query.snapshots().map((s) =>
        s.docs.map((d) => Sale(d.id, d.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Stream<List<Expense>> watchExpenses() => expenses
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Expense(d.id, d.data())).toList());
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStockMovements() => db
      .collection('stock_movements')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile() async* {
    final user = auth.currentUser!;
    final ref = db.collection('users').doc(user.uid);
    final initial = await ref.get().timeout(const Duration(seconds: 20));
    if (initial.exists) {
      yield initial;
      if (initial.data()?['email'] != user.email && user.email != null) {
        unawaited(ref.update({'email': user.email}).catchError((Object error) {
          debugPrint('Profile email sync failed');
        }));
      }
    } else {
      await db.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists) {
          tx.set(ref, {
            'email': user.email ?? '',
            'role': 'staff',
            'active': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }).timeout(const Duration(seconds: 20));
    }
    yield* ref.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAccounts() =>
      db.collection('users').snapshots();
  Future<void> setAccountAccess(String id, bool active) async {
    if (id == uid) throw StateError('You cannot change your own access.');
    await db
        .collection('users')
        .doc(id)
        .update({'active': active, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> setAccountRole(String id, String role) async {
    if (id == uid ||
        !['cashier', 'inventory', 'customer', 'staff'].contains(role)) {
      throw ArgumentError('Invalid role change');
    }
    await db
        .collection('users')
        .doc(id)
        .update({'role': role, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> sendAccountReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
  Future<void> saveProduct(Product p) async {
    final data = p.toMap()..remove('updatedAt');
    await operate('saveProduct', {'id': p.id, 'product': data});
  }

  Future<void> adjustStock(Product p, int delta, String reason) async {
    await operate(
        'adjustStock', {'id': p.id, 'delta': delta, 'reason': reason.trim()});
  }

  Future<String> checkout(List<CartLine> cart,
      {required String method,
      required double amountPaid,
      required String customer,
      String paymentReference = '',
      bool paymentVerified = false,
      String? requestId}) async {
    final result = await operate(
        'checkout',
        {
          'items': cart
              .map((l) => {'productId': l.product.id, 'quantity': l.quantity})
              .toList(),
          'method': method,
          'amountPaid': amountPaid,
          'customer': customer.trim(),
          'paymentReference': paymentReference.trim(),
          'paymentVerified': paymentVerified,
        },
        requestId: requestId);
    return result['id'] as String;
  }

  Future<String> createCustomerOrder(List<CartLine> cart,
      {required String deliveryMode,
      required String paymentMethod,
      String paymentReference = '',
      String? requestId}) async {
    final result = await operate('createOrder', {
      'items': cart.map((l) => {'productId': l.product.id, 'quantity': l.quantity}).toList(),
      'deliveryMode': deliveryMode,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference.trim(),
    }, requestId: requestId);
    return result['id'] as String;
  }

  Future<void> addExpense(String description, String category, double amount,
      {DateTime? expenseDate}) async {
    await operate('addExpense', {
      'description': description.trim(),
      'category': category,
      'amount': amount,
      'date': (expenseDate ?? DateTime.now()).toUtc().toIso8601String()
    });
  }

  Future<void> publishExistingData() async {
    for (final collection in ['products', 'sales']) {
      String? after;
      do {
        final result = await operate('publish',
            {'collection': collection, if (after != null) 'after': after});
        after = result['after'] as String?;
      } while (after != null);
    }
  }
}
