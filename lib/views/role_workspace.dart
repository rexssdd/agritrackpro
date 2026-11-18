import 'package:flutter/material.dart';
import '../models/store_role.dart';
import '../services/store_repository.dart';
import '../expensees/expenses_view.dart';
import 'cashier/receipts_view.dart';
import 'customer/customer_order_view.dart';
import 'orders_view.dart';
import '../widgets/confirm_dialog.dart';
import 'inventory/stock_history_view.dart';
import 'inventory_view.dart';
import 'sales_view.dart';
import '../config/theme.dart';
import 'staff/staff_dashboard_view.dart';
import 'customer/customer_dashboard_view.dart';

class RoleWorkspace extends StatefulWidget {
  const RoleWorkspace(
      {super.key,
      required this.repo,
      required this.role,
      this.inventoryAccess = false});
  final StoreRepository repo;
  final StoreRole role;
  final bool inventoryAccess;
  @override
  State<RoleWorkspace> createState() => _RoleWorkspaceState();
}

class _RoleWorkspaceState extends State<RoleWorkspace> {
  int selected = 0;
  late List<(String, IconData, Widget)> destinations;

  @override
  void initState() {
    super.initState();
    destinations = buildDestinations();
  }

  @override
  void didUpdateWidget(covariant RoleWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role ||
        oldWidget.inventoryAccess != widget.inventoryAccess ||
        oldWidget.repo != widget.repo) {
      destinations = buildDestinations();
      selected = 0;
    }
  }

  List<(String, IconData, Widget)> buildDestinations() => [
        if (widget.role == StoreRole.staff)
          (
            'Home',
            Icons.home_outlined,
            StaffDashboardView(
                repo: widget.repo,
                onOpen: (index) => setState(() => selected = index))
          ),
        if (widget.role.canSell) ...[
          ('Checkout', Icons.point_of_sale, SalesView(repo: widget.repo)),
          ('Receipts', Icons.receipt_long, ReceiptsView(repo: widget.repo)),
          if (widget.role == StoreRole.cashier ||
              widget.role == StoreRole.staff)
            (
              'Orders',
              Icons.pending_actions,
              OrdersView(repo: widget.repo, customer: false)
            ),
        ],
        if (widget.role.canManageInventory ||
            widget.role == StoreRole.staff) ...[
          (
            'Inventory',
            Icons.inventory_2_outlined,
            InventoryView(
                repo: widget.repo,
                isOwner: false,
                canEditProducts:
                    widget.role.canEditProducts || widget.inventoryAccess,
                canAdjustStock:
                    widget.role.canManageInventory || widget.inventoryAccess)
          ),
          if (widget.role.canManageInventory || widget.inventoryAccess)
            ('Movements', Icons.history, StockHistoryView(repo: widget.repo)),
        ],
        if (widget.role.canRecordExpenses)
          (
            'Expenses',
            Icons.payments_outlined,
            ExpensesView(repo: widget.repo, isOwner: true)
          ),
        if (widget.role == StoreRole.customer) ...[
          (
            'Home',
            Icons.home_outlined,
            CustomerDashboardView(
                repo: widget.repo,
                onShop: () => setState(() => selected = 1),
                onOrders: () => setState(() => selected = 2))
          ),
          ('Shop', Icons.storefront, CustomerOrderView(repo: widget.repo)),
          (
            'Orders',
            Icons.receipt_long,
            OrdersView(repo: widget.repo, customer: true)
          ),
        ],
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text('AgriTrack Pro',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AgriTheme.darkGreen)),
            actions: [
              IconButton(
                  tooltip: 'Sign out',
                  onPressed: () async {
                    if (await confirmLogout(context)) {
                      await widget.repo.auth.signOut();
                    }
                  },
                  icon: const Icon(Icons.logout)),
            ]),
        body: IndexedStack(
            index: selected, children: destinations.map((d) => d.$3).toList()),
        bottomNavigationBar: widget.role == StoreRole.staff
            ? NavigationBar(
                selectedIndex: switch (selected) {
                  0 => 0,
                  1 => 1,
                  4 => 2,
                  _ => 3
                },
                onDestinationSelected: (index) async {
                  if (index < 3) {
                    setState(() => selected = [0, 1, 4][index]);
                    return;
                  }
                  final target = await showModalBottomSheet<int>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: const Text('Sales history'),
                          onTap: () => Navigator.pop(context, 2)),
                      ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: const Text('Customer orders'),
                          onTap: () => Navigator.pop(context, 3)),
                      if (widget.inventoryAccess)
                        ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('Stock movements'),
                            onTap: () => Navigator.pop(context, 5)),
                    ])),
                  );
                  if (target != null && mounted) {
                    setState(() => selected = target);
                  }
                },
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined), label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined), label: 'Sales'),
                  NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      label: 'Inventory'),
                  NavigationDestination(
                      icon: Icon(Icons.more_horiz), label: 'More'),
                ],
              )
            : destinations.length < 2
                ? null
                : NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: (value) =>
                        setState(() => selected = value),
                    destinations: destinations
                        .map((d) => NavigationDestination(
                            icon: Icon(d.$2), label: d.$1))
                        .toList(),
                  ),
      );
}
