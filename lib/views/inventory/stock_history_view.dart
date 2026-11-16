import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/common.dart';

class StockHistoryView extends StatefulWidget {
  const StockHistoryView({super.key, required this.repo});
  final StoreRepository repo;
  @override
  State<StockHistoryView> createState() => _StockHistoryViewState();
}

class _StockHistoryViewState extends State<StockHistoryView> {
  String search = '';
  late final movements = widget.repo.watchStockMovements();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: movements,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load stock history.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs
              .where((d) => '${d.data()['productName']} ${d.data()['reason']}'
                  .toLowerCase()
                  .contains(search.toLowerCase()))
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Stock movement history',
                style: Theme.of(context).textTheme.headlineSmall),
            const Text(
                'Latest 300 movements, including restocking, deductions, opening stock and sales.'),
            TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(
                    labelText: 'Search product or reason',
                    prefixIcon: Icon(Icons.search))),
            if (docs.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No stock movements found.')),
            for (final doc in docs)
              Builder(builder: (context) {
                final m = doc.data();
                final delta = n(m['delta']).toInt();
                return Card(
                    child: ListTile(
                  leading: Icon(delta > 0
                      ? Icons.add_box_outlined
                      : Icons.remove_circle_outline),
                  title: Text(
                      '${m['productName']} (${delta > 0 ? '+' : ''}$delta)'),
                  subtitle: Text(
                      '${m['reason']}\n${stamp(date(m['createdAt']))}\nEmployee: ${m['userId']}'
                      '${m.containsKey('before') ? '\nBalance: ${m['before']} → ${m['after']}' : ''}'),
                ));
              }),
          ]);
        },
      );
}
