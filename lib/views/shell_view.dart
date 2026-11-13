import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/store_repository.dart';
import 'dashboard_view.dart';
import 'inventory_view.dart';
import 'sales_view.dart';
import 'reports_view.dart';
import 'expenses_view.dart';

class ShellView extends StatefulWidget {
  const ShellView({super.key});
  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  int tab = 0;
  final repo = StoreRepository();
  @override
  Widget build(BuildContext context) => StreamBuilder(
      stream: repo.watchProfile(),
      builder: (context, s) {
        if (s.hasError) {
          return Scaffold(
              body: Center(
                  child: Text('Unable to load staff profile: ${s.error}')));
        }
        if (!s.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = s.data!.data();
        if (data == null || data['active'] != true) {
          return Scaffold(
              appBar: AppBar(title: const Text('Access pending')),
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Ask the owner to activate your staff profile.'),
                TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Sign out'))
              ])));
        }
        final isOwner = data['role'] == 'owner';
        final pages = [
          DashboardView(repo: repo),
          InventoryView(repo: repo, isOwner: isOwner),
          SalesView(repo: repo),
          ReportsView(repo: repo),
          ExpensesView(repo: repo, isOwner: isOwner)
        ];
        return Scaffold(
            appBar: AppBar(
                title: const Text('AgriTrack Pro',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                      tooltip: 'Sign out',
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout))
                ]),
            body: IndexedStack(index: tab, children: pages),
            bottomNavigationBar: NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (v) => setState(() => tab = v),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
                  NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined), label: 'Sales'),
                  NavigationDestination(
                      icon: Icon(Icons.bar_chart), label: 'Reports'),
                  NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      label: 'Expenses')
                ]));
      });
}
