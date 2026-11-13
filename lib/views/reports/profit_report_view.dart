import 'package:flutter/material.dart';
import '../../services/store_service.dart';
import '../../utils/formatters.dart';

class ProfitReportView extends StatelessWidget {
  const ProfitReportView({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreService.instance;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Profit Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _reportLine('Revenue', store.revenue),
      _reportLine('Cost of Products Sold', store.costOfGoods),
      _reportLine('Operating Expenses', store.operatingExpenses),
      const Divider(),
      _reportLine('Estimated Net Profit', store.estimatedProfit, bold: true),
      const SizedBox(height: 16),
      const Text('Profit estimates are based on recorded sales and expenses. Taxes and other unrecorded costs are excluded.'),
    ]);
  }
  Widget _reportLine(String label, double value, {bool bold = false}) => Card(child: ListTile(
    title: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    trailing: Text(peso(value), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
  ));
}
