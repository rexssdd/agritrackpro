import 'package:flutter/material.dart';
import '../../services/store_repository.dart';
import '../../models/entities.dart';
import '../../widgets/common.dart';
import '../../widgets/agri_ui.dart';

class DashboardView extends StatelessWidget {
  final StoreRepository repo;
  final ValueChanged<int>? onOpen;
  const DashboardView({super.key, required this.repo, this.onOpen});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Sale>>(
      stream: repo.watchSalesForPeriod(
          DateTime(DateTime.now().year, DateTime.now().month),
          DateTime(DateTime.now().year, DateTime.now().month + 1)),
      builder: (context, s) => StreamBuilder<List<Product>>(
          stream: repo.watchProducts(),
          builder: (context, p) => StreamBuilder<List<Expense>>(
              stream: repo.watchExpensesForPeriod(
                  DateTime(DateTime.now().year, DateTime.now().month),
                  DateTime(DateTime.now().year, DateTime.now().month + 1)),
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
                final week = List.generate(7, (index) {
                  final day =
                      DateTime(now.year, now.month, now.day - 6 + index);
                  final total = s.data!
                      .where((sale) =>
                          sale.createdAt.year == day.year &&
                          sale.createdAt.month == day.month &&
                          sale.createdAt.day == day.day)
                      .fold<double>(0, (sum, sale) => sum + sale.total);
                  return (day, total);
                });
                final largestDay = week.fold<double>(
                    1, (largest, day) => day.$2 > largest ? day.$2 : largest);
                return ListView(padding: const EdgeInsets.all(16), children: [
                  const AgriHero(
                      title: 'Good day, Owner!',
                      subtitle: 'Your store at a glance',
                      icon: Icons.storefront_outlined),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                      builder: (context, constraints) => GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio:
                                  constraints.maxWidth > 600 ? 2.2 : 1.28,
                              children: [
                                AgriMetricCard(
                                    title: 'Today’s sales',
                                    value: peso(daySales),
                                    icon: Icons.payments),
                                AgriMetricCard(
                                    title: 'Total inventory',
                                    value:
                                        '${p.data!.where((x) => x.active).length} items',
                                    icon: Icons.inventory_2_outlined,
                                    color: Color(0xFF1963A5),
                                    background: Color(0xFFEAF3FC)),
                                AgriMetricCard(
                                    title: 'Month expenses',
                                    value: peso(expenses),
                                    icon: Icons.payments_outlined,
                                    color: Color(0xFFA56700),
                                    background: Color(0xFFFFF6E5)),
                                AgriMetricCard(
                                    title: 'Month net profit',
                                    value: peso(revenue - cost - expenses),
                                    icon: Icons.account_balance_wallet)
                              ])),
                  const AgriSectionTitle('Sales performance'),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Last 7 days',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 16),
                                SizedBox(
                                    height: 128,
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: week
                                            .map((entry) => Expanded(
                                                    child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                      Tooltip(
                                                          message:
                                                              peso(entry.$2),
                                                          child: Container(
                                                              height: 8 +
                                                                  86 *
                                                                      entry.$2 /
                                                                      largestDay,
                                                              margin:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5),
                                                              decoration: BoxDecoration(
                                                                  color: const Color(
                                                                      0xFF12934A),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6)))),
                                                      const SizedBox(height: 7),
                                                      Text(
                                                          const [
                                                            'Mon',
                                                            'Tue',
                                                            'Wed',
                                                            'Thu',
                                                            'Fri',
                                                            'Sat',
                                                            'Sun'
                                                          ][entry.$1.weekday -
                                                              1],
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      11)),
                                                    ])))
                                            .toList())),
                              ]))),
                  const AgriSectionTitle('Quick actions'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ActionChip(
                        avatar: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Manage inventory'),
                        onPressed: () => onOpen?.call(1)),
                    ActionChip(
                        avatar: const Icon(Icons.point_of_sale_outlined),
                        label: const Text('Sales'),
                        onPressed: () => onOpen?.call(2)),
                    ActionChip(
                        avatar: const Icon(Icons.bar_chart_outlined),
                        label: const Text('Reports'),
                        onPressed: () => onOpen?.call(4)),
                    ActionChip(
                        avatar: const Icon(Icons.people_outline),
                        label: const Text('Manage staff'),
                        onPressed: () => onOpen?.call(3)),
                  ]),
                  const AgriSectionTitle('Low stock alerts'),
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
                  const AgriSectionTitle('Recent transactions'),
                  ...s.data!.take(5).map((x) => Card(
                      child: ListTile(
                          title: Text(peso(x.total)),
                          subtitle: Text('${stamp(x.createdAt)} • ${x.method}'),
                          trailing: const Icon(Icons.check_circle,
                              color: Colors.green))))
                ]);
              })));
}
