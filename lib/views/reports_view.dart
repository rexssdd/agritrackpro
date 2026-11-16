import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import '../widgets/common.dart';

class ReportsView extends StatefulWidget {
  final StoreRepository repo;
  const ReportsView({super.key, required this.repo});
  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  String period = 'This month';
  DateTime get start {
    final now = DateTime.now();
    return switch (period) {
      'Today' => DateTime(now.year, now.month, now.day),
      'This year' => DateTime(now.year),
      _ => DateTime(now.year, now.month),
    };
  }

  DateTime get end {
    final now = DateTime.now();
    return switch (period) {
      'Today' => DateTime(now.year, now.month, now.day + 1),
      'This year' => DateTime(now.year + 1),
      _ => DateTime(now.year, now.month + 1),
    };
  }

  bool matches(DateTime d) {
    final now = DateTime.now();
    switch (period) {
      case 'Today':
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case 'This year':
        return d.year == now.year;
      default:
        return d.year == now.year && d.month == now.month;
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Sale>>(
      stream: widget.repo.watchSalesForPeriod(start, end),
      builder: (context, s) => StreamBuilder<List<Expense>>(
          stream: widget.repo.watchExpensesForPeriod(start, end),
          builder: (context, e) {
            if (s.hasError || e.hasError) {
              return const Center(
                  child: Text(
                      'Unable to load financial reports. Check your owner access and connection.'));
            }
            if (!s.hasData || !e.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final sales = s.data!.where((x) => matches(x.createdAt)).toList(),
                expenses = e.data!.where((x) => matches(x.createdAt)).toList();
            final revenue = sales.fold<double>(0, (a, b) => a + b.total),
                cogs = sales.fold<double>(0, (a, b) => a + b.cost),
                spend = expenses.fold<double>(0, (a, b) => a + b.amount),
                profit = revenue - cogs - spend;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('Sales & profit',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  initialValue: period,
                  decoration: const InputDecoration(labelText: 'Report period'),
                  items: ['Today', 'This month', 'This year']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (x) => setState(() => period = x!)),
              const SizedBox(height: 14),
              GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.45,
                  children: [
                    MetricTile(
                        title: 'Revenue',
                        value: peso(revenue),
                        icon: Icons.payments),
                    MetricTile(
                        title: 'Cost of goods',
                        value: peso(cogs),
                        icon: Icons.shopping_bag),
                    MetricTile(
                        title: 'Expenses',
                        value: peso(spend),
                        icon: Icons.receipt_long),
                    MetricTile(
                        title: 'Gross profit',
                        value: peso(revenue - cogs),
                        icon: Icons.trending_up),
                    MetricTile(
                        title: 'Estimated net profit',
                        value: peso(profit),
                        icon: Icons.savings)
                  ]),
              const SizedBox(height: 18),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Profit breakdown',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            _bar('Sales', revenue, revenue, Colors.green),
                            _bar('Product cost', cogs, revenue, Colors.orange),
                            _bar('Operating expenses', spend, revenue,
                                Colors.red),
                            const Divider(),
                            Text('Net profit: ${peso(profit)}',
                                style: Theme.of(context).textTheme.titleMedium)
                          ]))),
              const SizedBox(height: 12),
              Text('${sales.length} completed transactions',
                  style: Theme.of(context).textTheme.titleMedium),
              const Text(
                  'Estimates use recorded product costs and operating expenses. These figures are not audited financial statements.',
                  style: TextStyle(color: Colors.black54, fontSize: 12))
            ]);
          }));
  Widget _bar(String title, double value, double max, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title • ${peso(value)}'),
        const SizedBox(height: 5),
        LinearProgressIndicator(
            value: max <= 0 ? 0 : (value / max).clamp(0, 1),
            color: color,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8))
      ]));
}
