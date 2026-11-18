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
  static const useCloudFunctions = true;

  Future<Map<String, dynamic>> operate(String action, Map<String, dynamic> data,
      {String? requestId}) async {
    if (!useCloudFunctions) {
      return operateDirect(action, data, requestId ?? newRequestId());
    }
    final response = await FirebaseFunctions.instance
        .httpsCallable('storeOperation')
        .call<dynamic>({
      ...data,
      'action': action,
      'requestId': requestId ?? newRequestId(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Map<String, dynamic> catalogData(Map<String, dynamic> p) => {
        for (final key in [
          'name',
          'category',
          'unit',
          'description',
          'imageBase64',
          'price',
          'stock',
          'reorderLevel',
          'active'
        ])
          if (p[key] != null) key: p[key],
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Future<Map<String, dynamic>> operateDirect(
      String action, Map<String, dynamic> data, String requestId) async {
    if (action == 'saveGcashQr') {
      await db.collection('store_settings').doc('gcash').set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid
      });
      return {'saved': true};
    }
    if (action == 'saveProduct') {
      final id = (data['id'] as String?)?.isNotEmpty == true
          ? data['id'] as String
          : requestId;
      final product = Map<String, dynamic>.from(data['product'] as Map)
        ..remove('updatedAt');
      final ref = products.doc(id);
      await ref.set({...product, 'updatedAt': FieldValue.serverTimestamp()});
      await db.collection('catalog').doc(id).set(catalogData(product));
      return {'id': id};
    }
    if (action == 'seed') {
      var count = 0;
      for (final raw in (data['products'] as List)) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item.remove('id') as String;
        final ref = products.doc(id);
        if (!(await ref.get()).exists) {
          await ref.set({...item, 'updatedAt': FieldValue.serverTimestamp()});
          await db.collection('catalog').doc(id).set(catalogData(item));
          count++;
        }
      }
      for (final raw in (data['expenses'] as List)) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item.remove('id') as String;
        await expenses.doc(id).set({
          ...item,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp()
        });
        count++;
      }
      return {'count': count};
    }
    if (action == 'adjustStock') {
      final ref = products.doc(data['id'] as String);
      await db.runTransaction((tx) async {
        final doc = await tx.get(ref);
        final before = n(doc.data()?['stock']).toInt();
        final after = before + (data['delta'] as int);
        if (after < 0) throw StateError('Not enough stock');
        tx.update(
            ref, {'stock': after, 'updatedAt': FieldValue.serverTimestamp()});
        tx.set(db.collection('catalog').doc(ref.id),
            catalogData({...doc.data()!, 'stock': after}));
        tx.set(db.collection('stock_movements').doc(), {
          'productId': ref.id,
          'productName': doc.data()?['name'],
          'delta': data['delta'],
          'before': before,
          'after': after,
          'reason': data['reason'],
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp()
        });
      });
      return {};
    }
    if (action == 'addExpense') {
      await expenses.doc(requestId).set({
        'description': data['description'],
        'category': data['category'],
        'amount': data['amount'],
        'createdBy': uid,
        'createdAt': Timestamp.fromDate(DateTime.parse(data['date'] as String))
      });
      return {};
    }
    if (action == 'createOrder') {
      final id = '${uid}_$requestId';
      final items = List<Map<String, dynamic>>.from((data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)));
      final refs =
          items.map((e) => products.doc(e['productId'] as String)).toList();
      final docs = await Future.wait(refs.map((r) => r.get()));
      var total = 0.0;
      final saved = <Map<String, dynamic>>[];
      for (var i = 0; i < docs.length; i++) {
        final p = docs[i].data()!;
        final q = items[i]['quantity'] as int;
        total += n(p['price']).toDouble() * q;
        saved.add({
          ...items[i],
          'name': p['name'],
          'unit': p['unit'],
          'price': p['price'],
          'subtotal': n(p['price']).toDouble() * q
        });
      }
      await db.collection('customer_orders').doc(id).set({
        'customerId': uid,
        'customerEmail': data['customerEmail'],
        'address': data['address'],
        'items': saved,
        'total': total,
        'deliveryMode': data['deliveryMode'],
        'paymentMethod': data['paymentMethod'],
        'paymentReference': data['paymentReference'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      return {'id': id};
    }
    if (action == 'checkout') {
      final items = List<Map<String, dynamic>>.from((data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)));
      final docs = await Future.wait(
          items.map((e) => products.doc(e['productId'] as String).get()));
      var total = 0.0;
      final saved = <Map<String, dynamic>>[];
      for (var i = 0; i < docs.length; i++) {
        final p = docs[i].data()!;
        final q = items[i]['quantity'] as int;
        if (n(p['stock']).toInt() < q) {
          throw StateError('Not enough stock for ${p['name']}');
        }
        total += n(p['price']).toDouble() * q;
        saved.add({
          ...items[i],
          'name': p['name'],
          'unit': p['unit'],
          'price': p['price'],
          'unitCost': p['cost'],
          'subtotal': n(p['price']).toDouble() * q
        });
      }
      final saleId = '${uid}_$requestId';
      final batch = db.batch();
      for (var i = 0; i < docs.length; i++) {
        final ref = products.doc(docs[i].id);
        final after =
            n(docs[i].data()?['stock']).toInt() - (items[i]['quantity'] as int);
        batch.update(
            ref, {'stock': after, 'updatedAt': FieldValue.serverTimestamp()});
        batch.set(db.collection('catalog').doc(ref.id),
            catalogData({...docs[i].data()!, 'stock': after}));
      }
      final sale = {
        'items': saved,
        'total': total,
        'cost': saved.fold<double>(0,
            (s, x) => s + n(x['unitCost']).toDouble() * (x['quantity'] as int)),
        'amountPaid': data['amountPaid'],
        'change': (data['amountPaid'] as num).toDouble() - total,
        'method': data['method'],
        'paymentReference': data['paymentReference'],
        'customer': data['customer'],
        'cashierId': uid,
        'createdAt': FieldValue.serverTimestamp()
      };
      batch.set(sales.doc(saleId), sale);
      batch.set(db.collection('receipts').doc(saleId), {
        ...sale,
        'items': saved
            .map((x) => Map<String, dynamic>.from(x)..remove('unitCost'))
            .toList()
      });
      await batch.commit();
      return {'id': saleId};
    }
    if (action == 'confirmOrder') {
      if (data['paymentVerified'] != true) {
        throw StateError('Payment receipt must be confirmed');
      }
      final orderRef =
          db.collection('customer_orders').doc(data['orderId'] as String);
      final orderDoc = await orderRef.get();
      final order = orderDoc.data()!;
      if (order['status'] != 'pending') {
        throw StateError('Order is no longer pending');
      }
      final items = List<Map<String, dynamic>>.from((order['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)));
      final docs = await Future.wait(
          items.map((e) => products.doc(e['productId'] as String).get()));
      final saleId = '${orderRef.id}_sale';
      final batch = db.batch();
      for (var i = 0; i < docs.length; i++) {
        final after =
            n(docs[i].data()?['stock']).toInt() - (items[i]['quantity'] as int);
        if (after < 0) throw StateError('Not enough stock');
        batch.update(products.doc(docs[i].id),
            {'stock': after, 'updatedAt': FieldValue.serverTimestamp()});
        batch.set(db.collection('catalog').doc(docs[i].id),
            catalogData({...docs[i].data()!, 'stock': after}));
      }
      final sale = {
        'items': items,
        'total': order['total'],
        'cost': 0,
        'amountPaid': order['total'],
        'change': 0,
        'method': order['paymentMethod'],
        'paymentReference': order['paymentReference'],
        'paymentVerified': true,
        'customer': order['customerId'],
        'customerId': order['customerId'],
        'cashierId': uid,
        'createdAt': FieldValue.serverTimestamp()
      };
      batch.set(sales.doc(saleId), sale);
      batch.set(db.collection('receipts').doc(saleId), sale);
      batch.update(orderRef, {
        'status': 'confirmed',
        'saleId': saleId,
        'confirmedBy': uid,
        'confirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      await batch.commit();
      return {'id': saleId};
    }
    if (action == 'publish') {
      final snapshot = await products.get();
      for (final doc in snapshot.docs) {
        await db.collection('catalog').doc(doc.id).set(catalogData(doc.data()));
      }
      return {'count': snapshot.size, 'after': null};
    }
    return {};
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
    final isGoogle = user.providerData
        .any((provider) => provider.providerId == 'google.com');
    final initial = await ref.get().timeout(const Duration(seconds: 20));
    if (initial.exists) {
      final existingRole = initial.data()?['role'];
      final shouldUseGoogleCustomerRole =
          isGoogle && existingRole != 'owner' && existingRole != 'customer';
      if ((initial.data()?['email'] != user.email && user.email != null) ||
          shouldUseGoogleCustomerRole) {
        // Repair profiles created before email syncing was added. Await this
        // write so owner account lists receive the email immediately after the
        // user signs in, instead of briefly showing "Email unavailable".
        try {
          final updates = <String, dynamic>{};
          if (user.email != null) updates['email'] = user.email;
          if (shouldUseGoogleCustomerRole) {
            updates.addAll({
              'role': 'customer',
              'active': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await ref.update(updates);
        } catch (error) {
          debugPrint('Profile email sync failed: $error');
        }
      }
      yield await ref.get();
    } else {
      await db.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists) {
          tx.set(ref, {
            'email': user.email ?? '',
            'role': isGoogle ? 'customer' : 'staff',
            'active': isGoogle,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }).timeout(const Duration(seconds: 20));
    }
    yield* ref.snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGcashSettings() =>
      db.collection('store_settings').doc('gcash').snapshots();

  Stream<List<CustomerOrder>> watchCustomerOrders() {
    Query<Map<String, dynamic>> query = db.collection('customer_orders');
    if (role == 'customer') query = query.where('customerId', isEqualTo: uid);
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CustomerOrder(d.id, d.data())).toList());
  }

  Future<void> saveGcashQr(String imageBase64) async {
    await operate('saveGcashQr', {'imageBase64': imageBase64});
  }

  Future<void> confirmCustomerOrder(String orderId) async {
    await operate('confirmOrder', {
      'orderId': orderId,
      'paymentVerified': true,
    });
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

  Future<void> setInventoryAccess(String id, bool enabled) async {
    if (id == uid) throw ArgumentError('Cannot change your own access');
    await db.collection('users').doc(id).update({
      'inventoryAccess': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      String address = '',
      String customerEmail = '',
      String? requestId}) async {
    final result = await operate(
        'createOrder',
        {
          'items': cart
              .map((l) => {'productId': l.product.id, 'quantity': l.quantity})
              .toList(),
          'deliveryMode': deliveryMode,
          'paymentMethod': paymentMethod,
          'paymentReference': paymentReference.trim(),
          'address': address.trim(),
          'customerEmail': customerEmail.trim(),
        },
        requestId: requestId);
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
