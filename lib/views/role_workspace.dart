import 'package:flutter/material.dart';
import '../models/store_role.dart';
import '../services/store_repository.dart';
import '../expensees/expenses_view.dart';
import 'cashier/receipts_view.dart';
import 'customer/customer_order_view.dart';
import 'inventory/stock_history_view.dart';
import 'inventory_view.dart';
import 'sales_view.dart';

class RoleWorkspace extends StatefulWidget {
  const RoleWorkspace({super.key, required this.repo, required this.role});
  final StoreRepository repo;
  final StoreRole role;
  @override
  State<RoleWorkspace> createState() => _RoleWorkspaceState();
}

class _RoleWorkspaceState extends State<RoleWorkspace> {
  int selected = 0;
  late final destinations = <(String, IconData, Widget)>[
    if (widget.role.canSell) ...[
      ('Checkout', Icons.point_of_sale, SalesView(repo: widget.repo)),
      ('Receipts', Icons.receipt_long, ReceiptsView(repo: widget.repo)),
    ],
    if (widget.role.canManageInventory) ...[
      (
        'Inventory',
        Icons.inventory_2_outlined,
        InventoryView(
            repo: widget.repo,
            isOwner: false,
            canEditProducts: widget.role.canEditProducts)
      ),
      ('Movements', Icons.history, StockHistoryView(repo: widget.repo)),
    ],
    if (widget.role.canRecordExpenses)
      (
        'Expenses',
        Icons.payments_outlined,
        ExpensesView(repo: widget.repo, isOwner: true)
      ),
    if (widget.role == StoreRole.customer)
      ('Order', Icons.storefront, CustomerOrderView(repo: widget.repo)),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.role.label} workspace'), actions: [
          IconButton(
              tooltip: 'Sign out',
              onPressed: () => widget.repo.auth.signOut(),
              icon: const Icon(Icons.logout)),
        ]),
        body: IndexedStack(
            index: selected, children: destinations.map((d) => d.$3).toList()),
        bottomNavigationBar: destinations.length < 2
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    setState(() => selected = value),
                destinations: destinations
                    .map((d) =>
                        NavigationDestination(icon: Icon(d.$2), label: d.$1))
                    .toList(),
              ),
      );
}
