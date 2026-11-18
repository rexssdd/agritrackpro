import 'package:agritrack_pro/models/entities.dart';
import 'package:agritrack_pro/models/store_role.dart';
import 'package:agritrack_pro/services/store_repository.dart';
import 'package:agritrack_pro/views/role_workspace.dart';
import 'package:agritrack_pro/views/customer/customer_dashboard_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WorkspaceRepo extends Fake implements StoreRepository {
  WorkspaceRepo(this.role, {this.featuredProducts = const []});
  @override
  final String role;
  final List<Product> featuredProducts;
  @override
  Stream<List<Product>> watchProducts() => Stream.value(featuredProducts);
  @override
  Stream<List<Sale>> watchReceipts() => Stream.value([]);
  @override
  Stream<List<CustomerOrder>> watchCustomerOrders() => Stream.value([]);
  @override
  Stream<List<Expense>> watchExpenses() => Stream.value([]);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStockMovements() =>
      const Stream.empty();
}

void main() {
  testWidgets('customer home filters live featured products on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = WorkspaceRepo('customer', featuredProducts: [
      Product(
          id: 'urea',
          name: 'Urea 46-0-0',
          category: 'Fertilizer',
          unit: 'sack',
          price: 950,
          cost: 700,
          stock: 8,
          reorderLevel: 10),
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomerDashboardView(
                repo: repo, onShop: () {}, onOrders: () {}))));
    await tester.pump();
    expect(find.text('Urea 46-0-0'), findsOneWidget);
    await tester.tap(find.text('Insecticide'));
    await tester.pump();
    expect(find.text('No matching products'), findsOneWidget);
  });
  test('roles restrict sensitive and operational capabilities', () {
    expect(StoreRole.customer.canSell, false);
    expect(StoreRole.cashier.canManageInventory, false);
    expect(StoreRole.staff.canManageInventory, false);
    expect(StoreRole.inventory.canSell, false);
    expect(StoreRole.inventory.canEditProducts, true);
    for (final role in StoreRole.values.where((r) => r != StoreRole.owner)) {
      expect(role.canViewProfit, false);
    }
    expect(StoreRole.parse('admin'), isNull);
  });
  testWidgets('staff inventory edits require an owner grant', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RoleWorkspace(
            repo: WorkspaceRepo('staff'), role: StoreRole.staff)));
    await tester.pump();
    await tester.tap(find.text('Inventory').last);
    await tester.pump();
    expect(find.text('Add product'), findsNothing);

    await tester.pumpWidget(MaterialApp(
        home: RoleWorkspace(
            repo: WorkspaceRepo('staff'),
            role: StoreRole.staff,
            inventoryAccess: true)));
    await tester.pump();
    await tester.tap(find.text('Inventory').last);
    await tester.pump();
    await tester.pump();
    expect(find.text('Add product'), findsOneWidget);
  });
  for (final role in [
    StoreRole.customer,
    StoreRole.cashier,
    StoreRole.inventory
  ]) {
    testWidgets('${role.name} has a dedicated workspace without profit reports',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: RoleWorkspace(repo: WorkspaceRepo(role.name), role: role)));
      await tester.pump();
      expect(find.text('AgriTrack Pro'), findsOneWidget);
      expect(find.text('Reports'), findsNothing);
      if (role == StoreRole.customer) {
        expect(find.text('Farm supplies\nfor better yield'), findsOneWidget);
        expect(find.text('Checkout'), findsNothing);
      } else if (role == StoreRole.cashier) {
        expect(find.text('Checkout'), findsOneWidget);
        expect(find.text('Inventory'), findsNothing);
      } else {
        expect(find.text('Movements'), findsOneWidget);
        expect(find.text('Checkout'), findsNothing);
        expect(find.text('Add product'), findsOneWidget);
      }
    });
  }
}
