import 'package:agritrack_pro/models/entities.dart';
import 'package:agritrack_pro/services/store_repository.dart';
import 'package:agritrack_pro/views/sales_view.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CheckoutRepo extends Fake implements StoreRepository {
  final requests = <String?>[];
  bool failOnce = false;
  @override
  Stream<List<Product>> watchProducts() => Stream.value([
        Product(
            id: 'rice',
            name: 'Rice',
            category: 'Seeds',
            unit: 'bag',
            price: 100,
            cost: 0,
            stock: 5,
            reorderLevel: 1),
      ]);
  @override
  Stream<List<Sale>> watchReceipts() => Stream.value([]);
  @override
  String newRequestId() => 'checkout-request';
  @override
  Future<String> checkout(List<CartLine> cart,
      {required String method,
      required double amountPaid,
      required String customer,
      String paymentReference = '',
      bool paymentVerified = false,
      String? requestId}) async {
    requests.add(requestId);
    if (failOnce) {
      failOnce = false;
      throw FirebaseFunctionsException(
          code: 'unavailable', message: 'Connection lost');
    }
    return 'receipt-123';
  }
}

void main() {
  Future<void> open(WidgetTester tester, CheckoutRepo repo) async {
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SalesView(repo: repo))));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Confirm payment & deduct stock'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Confirm payment & deduct stock'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'invalid payment amount leaves checkout editable without creating a request',
      (tester) async {
    final repo = CheckoutRepo();
    await open(tester, repo);
    await tester.tap(find.text('Confirm payment & deduct stock'));
    await tester.pumpAndSettle();
    expect(repo.requests, isEmpty);
    expect(
        find.textContaining('Enter a valid amount received.'), findsOneWidget);
    expect(find.text('Retry transaction'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Amount received (₱)'), '100');
    await tester.tap(find.text('Confirm payment & deduct stock'));
    await tester.pumpAndSettle();
    expect(repo.requests, ['checkout-request']);
  });
  testWidgets('uncertain checkout retries with the same request ID',
      (tester) async {
    final repo = CheckoutRepo()..failOnce = true;
    await open(tester, repo);
    await tester.enterText(
        find.widgetWithText(TextField, 'Amount received (₱)'), '100');
    await tester.tap(find.text('Confirm payment & deduct stock'));
    await tester.pumpAndSettle();
    expect(find.text('Retry transaction'), findsOneWidget);
    await tester.tap(find.text('Retry transaction'));
    await tester.pumpAndSettle();
    expect(repo.requests, ['checkout-request', 'checkout-request']);
    expect(find.text('Retry transaction'), findsNothing);
  });
}
