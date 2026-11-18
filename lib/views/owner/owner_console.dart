import 'package:flutter/material.dart';
import '../../services/store_repository.dart';
import '../../services/demo_seeder.dart';
import 'accounts_view.dart';
import 'dashboard_view.dart';
import '../../expensees/expenses_view.dart';
import '../inventory_view.dart';
import 'reports_view.dart';
import 'product_performance_view.dart';
import '../sales_view.dart';
import '../inventory/stock_history_view.dart';
import '../cashier/receipts_view.dart';
import 'gcash_settings_view.dart';
import '../../widgets/confirm_dialog.dart';
import '../../config/theme.dart';

/// Only mounted after the live profile confirms an active owner role.
class OwnerConsole extends StatefulWidget {
  const OwnerConsole({super.key, required this.repo});
  final StoreRepository repo;
  @override
  State<OwnerConsole> createState() => _OwnerConsoleState();
}

class _OwnerConsoleState extends State<OwnerConsole> {
  int selected = 0;
  bool seeding = false;
  bool publishing = false;

  Future<void> publish() async {
    setState(() => publishing = true);
    try {
      await widget.repo.publishExistingData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Existing catalog and receipts are ready for staff.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Publishing failed: $error')));
      }
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  Future<void> seedDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add sample store data?'),
        content: const Text(
            'Adds 8 sample products with illustrated images and 5 sample expenses to Firebase. These affect inventory and profit reports. Existing seed records are skipped.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Seed Firebase')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => seeding = true);
    try {
      final count = await DemoSeeder.seed(widget.repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Added $count sample records to Firebase.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Seeding failed: $error')));
      }
    } finally {
      if (mounted) setState(() => seeding = false);
    }
  }

  static const labels = [
    'Overview',
    'Products',
    'Sales',
    'Accounts',
    'Reports',
    'Expenses',
    'Stock history',
    'Receipts',
    'GCash QR',
    'Product performance'
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.point_of_sale_outlined,
    Icons.manage_accounts_outlined,
    Icons.bar_chart,
    Icons.receipt_long_outlined,
    Icons.history,
    Icons.receipt_long,
    Icons.qr_code_2,
    Icons.stacked_bar_chart_outlined
  ];
  late final pages = <Widget>[
    DashboardView(
        repo: widget.repo, onOpen: (index) => setState(() => selected = index)),
    InventoryView(repo: widget.repo, isOwner: true),
    SalesView(repo: widget.repo),
    AccountsView(repo: widget.repo),
    ReportsView(
        repo: widget.repo,
        onProductPerformance: () => setState(() => selected = 9)),
    ExpensesView(repo: widget.repo, isOwner: true),
    StockHistoryView(repo: widget.repo),
    ReceiptsView(repo: widget.repo),
    GcashSettingsView(repo: widget.repo),
    ProductPerformanceView(repo: widget.repo),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AgriTrack Pro',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AgriTheme.darkGreen)),
            Text(labels[selected],
                style: Theme.of(context).textTheme.labelMedium),
          ]),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Owner actions',
              onSelected: (action) {
                if (action == 'accounts') setState(() => selected = 3);
                if (action == 'publish') publish();
                if (action == 'seed') seedDemo();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'accounts',
                    child: ListTile(
                        leading: Icon(Icons.manage_accounts),
                        title: Text('Manage accounts'))),
                PopupMenuItem(
                    value: 'publish',
                    enabled: !publishing,
                    child: const ListTile(
                        leading: Icon(Icons.sync),
                        title: Text('Publish existing data'))),
                PopupMenuItem(
                    value: 'seed',
                    enabled: !seeding,
                    child: const ListTile(
                        leading: Icon(Icons.cloud_upload_outlined),
                        title: Text('Seed sample data'))),
              ],
            ),
            IconButton(
                tooltip: 'Sign out',
                onPressed: () async {
                  if (await confirmLogout(context)) {
                    await widget.repo.auth.signOut();
                  }
                },
                icon: const Icon(Icons.logout)),
          ],
        ),
        drawer: Drawer(
            child: SafeArea(
                child: ListView(children: [
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Owner management',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          for (var i = 0; i < labels.length; i++)
            ListTile(
              leading: Icon(icons[i]),
              title: Text(labels[i]),
              selected: selected == i,
              onTap: () {
                Navigator.pop(context);
                setState(() => selected = i);
              },
            ),
        ]))),
        body: IndexedStack(index: selected, children: pages),
        bottomNavigationBar: selected >= 4
            ? null
            : NavigationBar(
                selectedIndex: selected < 4 ? selected : 0,
                onDestinationSelected: (value) =>
                    setState(() => selected = value),
                destinations: [
                  for (var i = 0; i < 4; i++)
                    NavigationDestination(
                        icon: Icon(icons[i]), label: labels[i])
                ],
              ),
      );
}
