import 'package:flutter/material.dart';
import '../services/store_repository.dart';
import '../models/entities.dart';
import '../widgets/common.dart';

class DashboardView extends StatelessWidget {
  final StoreRepository repo;
  const DashboardView({super.key, required this.repo});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Sale>>(
      stream: repo.watchSales(),
      builder: (context, s) => StreamBuilder<List<Product>>(
          stream: repo.watchProducts(),
          builder: (context, p) => StreamBuilder<List<Expense>>(
              stream: repo.watchExpenses(),
              builder: (context, e) {
                if (s.hasError || p.hasError || e.hasError) {
                  return const Center(child: Text('Unable to load dashboard'));
                }
                if (!s.hasData || !p.hasData || !e.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final now = DateTime.now();
                bool today(DateTime d) =>
                    d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;
                bool month(DateTime d) =>
                    d.year == now.year && d.month == now.month;
                final daySales = s.data!
                    .where((x) => today(x.createdAt))
                    .fold<double>(0, (a, b) => a + b.total);
                final monthSales =
                    s.data!.where((x) => month(x.createdAt)).toList();
                final revenue =
                    monthSales.fold<double>(0, (a, b) => a + b.total);
                final cost = monthSales.fold<double>(0, (a, b) => a + b.cost);
                final expenses = e.data!
                    .where((x) => month(x.createdAt))
                    .fold<double>(0, (a, b) => a + b.amount);
                final low = p.data!
                    .where((x) => x.active && x.stock <= x.reorderLevel)
                    .toList();
                return ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Business overview',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Live sales, stock and profit at a glance'),
                  const SizedBox(height: 16),
                  GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.45,
                      children: [
                        MetricTile(
                            title: 'Today’s sales',
                            value: peso(daySales),
                            icon: Icons.payments),
                        MetricTile(
                            title: 'Month revenue',
                            value: peso(revenue),
                            icon: Icons.trending_up),
                        MetricTile(
                            title: 'Month net profit',
                            value: peso(revenue - cost - expenses),
                            icon: Icons.account_balance_wallet),
                        MetricTile(
                            title: 'Low stock items',
                            value: '${low.length}',
                            icon: Icons.warning_amber)
                      ]),
                  const SizedBox(height: 20),
                  Text('Stock alerts',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (low.isEmpty)
                    const Card(
                        child: ListTile(
                            title: Text('All products above reorder level'))),
                  ...low.take(6).map((x) => Card(
                      child: ListTile(
                          leading: Icon(
                              x.stock == 0
                                  ? Icons.error_outline
                                  : Icons.inventory_2_outlined,
                              color: Colors.orange),
                          title: Text(x.name),
                          subtitle: Text(
                              'Remaining ${x.stock} ${x.unit} • reorder at ${x.reorderLevel}')))),
                  const SizedBox(height: 12),
                  Text('Recent transactions',
                      style: Theme.of(context).textTheme.titleLarge),
                  ...s.data!.take(5).map((x) => Card(
                      child: ListTile(
                          title: Text(peso(x.total)),
                          subtitle: Text('${stamp(x.createdAt)} • ${x.method}'),
                          trailing: const Icon(Icons.check_circle,
                              color: Colors.green))))
                ]);
              })));
}
