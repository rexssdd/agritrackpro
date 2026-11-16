import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/common.dart';

void showReceipt(BuildContext context, Sale sale) {
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('Transaction summary'),
            content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                    child: SelectionArea(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('AgriTrack Pro • Agri Supply',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Receipt: ${sale.id}'),
                    Text(stamp(sale.createdAt)),
                    if (sale.customer.isNotEmpty)
                      Text('Customer: ${sale.customer}'),
                    const Divider(),
                    for (final raw in sale.items)
                      Builder(builder: (context) {
                        final item = Map<String, dynamic>.from(raw as Map);
                        return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                                '${item['name']}\n${item['quantity']} ${item['unit']} × ${peso(n(item['price']).toDouble())} = ${peso(n(item['subtotal']).toDouble())}'));
                      }),
                    const Divider(),
                    Text('Total: ${peso(sale.total)}'),
                    Text('Amount received: ${peso(sale.amountPaid)}'),
                    Text('Change: ${peso(sale.amountPaid - sale.total)}'),
                    Text('Payment: ${sale.method}'),
                    if (sale.paymentReference.isNotEmpty)
                      Text('Reference: ${sale.paymentReference}'),
                    const SizedBox(height: 8),
                    const Text(
                        'Digital transaction summary. Keep this receipt ID for inquiries.'),
                  ],
                )))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));
}

class ReceiptsView extends StatefulWidget {
  const ReceiptsView({super.key, required this.repo});
  final StoreRepository repo;
  @override
  State<ReceiptsView> createState() => _ReceiptsViewState();
}

class _ReceiptsViewState extends State<ReceiptsView> {
  late final receipts = widget.repo.watchReceipts();
  String search = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Sale>>(
        stream: receipts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load receipts.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!
              .where((s) => '${s.id} ${s.customer} ${s.method}'
                  .toLowerCase()
                  .contains(search.toLowerCase()))
              .toList();
          final today = DateUtils.dateOnly(DateTime.now());
          final daily = snapshot.data!
              .where((s) => !s.createdAt.isBefore(today))
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(widget.repo.role == 'owner' ? 'Store receipts' : 'My receipts',
                style: Theme.of(context).textTheme.headlineSmall),
            Text(
                '${daily.length} sales today • ${peso(daily.fold<double>(0, (sum, s) => sum + s.total))} collected'),
            for (final method in ['Cash', 'GCash', 'Bank transfer'])
              Text(
                  '$method: ${peso(daily.where((s) => s.method == method).fold<double>(0, (sum, s) => sum + s.total))}'),
            TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(
                    labelText: 'Search receipt, customer or payment method',
                    prefixIcon: Icon(Icons.search))),
            if (items.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No receipts found.')),
            for (final sale in items)
              Card(
                  child: ListTile(
                      title: Text(peso(sale.total)),
                      subtitle: Text(
                          '${stamp(sale.createdAt)} • ${sale.method}\n${sale.customer.isEmpty ? 'Walk-in customer' : sale.customer}'),
                      trailing: const Icon(Icons.receipt_long),
                      onTap: () => showReceipt(context, sale))),
          ]);
        },
      );
}
