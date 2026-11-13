import 'package:flutter/material.dart';
import '../../services/store_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/metric_card.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreService.instance;
    final today = DateTime.now();
    final todaySales = store.sales.where((s) => s.createdAt.year == today.year && s.createdAt.month == today.month && s.createdAt.day == today.day).fold<double>(0, (sum, s) => sum + s.total);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Business Overview', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2,
        childAspectRatio: 1.4, children: [
          MetricCard(label: 'Today Sales', value: peso(todaySales), icon: Icons.point_of_sale),
          MetricCard(label: 'Total Revenue', value: peso(store.revenue), icon: Icons.payments),
          MetricCard(label: 'Estimated Profit', value: peso(store.estimatedProfit), icon: Icons.trending_up),
          MetricCard(label: 'Low / Out of Stock', value: '${store.products.where((p) => p.stock <= p.reorderLevel).length}', icon: Icons.warning_amber),
        ]),
      const SizedBox(height: 20),
      const Text('Stock Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ...store.products.where((p) => p.stock <= p.reorderLevel).map((p) => ListTile(
        leading: const Icon(Icons.inventory_2_outlined), title: Text(p.name),
        subtitle: Text(p.stockStatus), trailing: Text('${p.stock} left'))),
    ]);
  }
}
