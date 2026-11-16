import 'package:agritrack_pro/models/entities.dart';
import 'package:agritrack_pro/models/store_role.dart';
import 'package:agritrack_pro/services/store_repository.dart';
import 'package:agritrack_pro/views/role_workspace.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WorkspaceRepo extends Fake implements StoreRepository {
  WorkspaceRepo(this.role);
  @override
  final String role;
  @override
  Stream<List<Product>> watchProducts() => Stream.value([]);
  @override
  Stream<List<Sale>> watchReceipts() => Stream.value([]);
  @override
  Stream<List<Expense>> watchExpenses() => Stream.value([]);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchStockMovements() =>
      const Stream.empty();
}

void main() {
  test('roles restrict sensitive and operational capabilities', () {
    expect(StoreRole.customer.canSell, false);
    expect(StoreRole.cashier.canManageInventory, false);
    expect(StoreRole.inventory.canSell, false);
    expect(StoreRole.inventory.canEditProducts, true);
    for (final role in StoreRole.values.where((r) => r != StoreRole.owner)) {
      expect(role.canViewProfit, false);
    }
    expect(StoreRole.parse('admin'), isNull);
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
      expect(find.text('${role.label} workspace'), findsOneWidget);
      expect(find.text('Reports'), findsNothing);
      if (role == StoreRole.customer) {
        expect(find.text('Agri Supply catalog'), findsOneWidget);
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
