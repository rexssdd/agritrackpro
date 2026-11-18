import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/agri_ui.dart';
import '../../widgets/common.dart';

class StaffDashboardView extends StatelessWidget {
  const StaffDashboardView(
      {super.key, required this.repo, required this.onOpen});
  final StoreRepository repo;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
        stream: repo.watchProducts(),
        builder: (context, productsSnapshot) {
          final products = productsSnapshot.data ?? <Product>[];
          final low = products
              .where((p) => p.active && p.stock <= p.reorderLevel)
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const CircleAvatar(
                          radius: 25,
                          backgroundColor: Color(0xFFE2F4E7),
                          child: Icon(Icons.person,
                              color: Color(0xFF00672E), size: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Good day, Staff!',
                                style: Theme.of(context).textTheme.titleLarge),
                            const Text('Store Staff',
                                style: TextStyle(color: Color(0xFF65746A))),
                          ])),
                      IconButton(
                        tooltip: '${low.length} low-stock alerts',
                        onPressed: () => onOpen(4),
                        icon: Badge(
                            isLabelVisible: low.isNotEmpty,
                            label: Text('${low.length}'),
                            child: const Icon(Icons.notifications_outlined)),
                      ),
                    ]))),
            const AgriSectionTitle('Quick actions'),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.48,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _action('Record sale', Icons.point_of_sale_outlined, 1),
                _action('Products & stock', Icons.inventory_2_outlined, 4),
                _action('Sales history', Icons.receipt_long_outlined, 2),
                _action('Customer orders', Icons.local_shipping_outlined, 3),
              ],
            ),
            const AgriSectionTitle('Today’s summary'),
            StreamBuilder<List<Sale>>(
              stream: repo.watchReceipts(),
              builder: (context, salesSnapshot) {
                final now = DateTime.now();
                final today = salesSnapshot.data
                        ?.where((sale) =>
                            sale.createdAt.year == now.year &&
                            sale.createdAt.month == now.month &&
                            sale.createdAt.day == now.day)
                        .toList() ??
                    <Sale>[];
                final revenue =
                    today.fold<double>(0, (sum, sale) => sum + sale.total);
                return Card(
                    child: Column(children: [
                  _summary(
                      Icons.shopping_cart_outlined,
                      'Your sales today',
                      peso(revenue),
                      const Color(0xFFEAF7EA),
                      const Color(0xFF00672E)),
                  const Divider(height: 1),
                  _summary(
                      Icons.receipt_long_outlined,
                      'Transactions',
                      '${today.length}',
                      const Color(0xFFEAF3FC),
                      const Color(0xFF1963A5)),
                  const Divider(height: 1),
                  _summary(
                      Icons.warning_amber_rounded,
                      'Low-stock items',
                      '${low.length}',
                      const Color(0xFFFFF6E5),
                      const Color(0xFFA56700)),
                ]));
              },
            ),
            const AgriSectionTitle('Stock alerts'),
            if (productsSnapshot.hasError)
              const Card(
                  child: ListTile(title: Text('Unable to load stock alerts')))
            else if (!productsSnapshot.hasData)
              const LinearProgressIndicator()
            else if (low.isEmpty)
              const Card(
                  child: ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Stock levels look good')))
            else
              ...low.take(4).map((p) => Card(
                      child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFA56700)),
                    title: Text(p.name),
                    subtitle: Text('${p.stock} ${p.unit} remaining'),
                    onTap: () => onOpen(4),
                  ))),
          ]);
        },
      );

  Widget _action(String label, IconData icon, int index) => Card(
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onOpen(index),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: const Color(0xFF00672E), size: 29),
                      const SizedBox(height: 8),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]))),
      );

  Widget _summary(IconData icon, String label, String value, Color background,
          Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          CircleAvatar(
              backgroundColor: background,
              radius: 17,
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      );
}
