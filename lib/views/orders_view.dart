import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import '../widgets/common.dart';

class OrdersView extends StatefulWidget {
  const OrdersView({super.key, required this.repo, required this.customer});
  final StoreRepository repo;
  final bool customer;
  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  bool busy = false;

  Stream<List<CustomerOrder>> ordersStream() {
    try {
      return widget.repo.watchCustomerOrders();
    } on UnimplementedError {
      // Keeps lightweight workspace fakes usable in widget tests.
      return Stream.value(const <CustomerOrder>[]);
    }
  }

  Future<void> confirm(CustomerOrder order) async {
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment'),
        content: Text(order.paymentMethod == 'GCash'
            ? 'Verify the GCash payment independently using the reference shown on this order. A reference alone is not proof of payment.'
            : 'Confirm that payment has been received before completing this sale.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Payment received')),
        ],
      ),
    );
    if (verified != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repo.confirmCustomerOrder(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment confirmed and receipt created.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to confirm order: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Uint8List> receiptPdf(CustomerOrder order) async {
    final document = pw.Document();
    document.addPage(pw.Page(
        build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('AgriTrack Pro - Agri Supply',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Receipt: ${order.saleId.isEmpty ? order.id : order.saleId}'),
                pw.Text(stamp(order.createdAt)),
                pw.SizedBox(height: 12),
                ...order.items.map((raw) => pw.Text(
                    '${raw['name']} x ${raw['quantity']} = ${peso(n(raw['subtotal']).toDouble())}')),
                pw.Divider(),
                pw.Text('Total: ${peso(order.total)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Delivery: ${order.deliveryMode}'),
                pw.Text('Payment: ${order.paymentMethod}'),
                if (order.paymentReference.isNotEmpty)
                  pw.Text('Reference: ${order.paymentReference}'),
              ],
            )));
    return Uint8List.fromList(await document.save());
  }

  void showOrder(CustomerOrder order) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(order.status == 'confirmed' ? 'Receipt' : 'Preorder'),
          content: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Order: ${order.id}'),
                if (order.customerEmail.isNotEmpty)
                  Text('Customer email: ${order.customerEmail}'),
                if (order.address.isNotEmpty) Text('Address: ${order.address}'),
                Text('Date: ${stamp(order.createdAt)}'),
                Text('Status: ${order.status}'),
                Text('Delivery: ${order.deliveryMode}'),
                Text('Payment: ${order.paymentMethod}'),
                if (order.paymentReference.isNotEmpty)
                  Text('Reference: ${order.paymentReference}'),
                const Divider(),
                for (final raw in order.items)
                  Text(
                      '${raw['name']} × ${raw['quantity']} = ${peso(n(raw['subtotal']).toDouble())}'),
                const Divider(),
                Text('Total: ${peso(order.total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (order.saleId.isNotEmpty)
                  Text('Receipt ID: ${order.saleId}'),
                if (order.status == 'confirmed')
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                          'This receipt can be printed or saved using your device print/screenshot tools.')),
              ])),
          actions: [
            if (order.status == 'confirmed') ...[
              TextButton(
                  onPressed: () async =>
                      Printing.layoutPdf(onLayout: (_) => receiptPdf(order)),
                  child: const Text('Print')),
              TextButton(
                  onPressed: () async => Printing.sharePdf(
                      bytes: await receiptPdf(order),
                      filename: 'receipt-${order.id}.pdf'),
                  child: const Text('Share/email')),
            ],
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CustomerOrder>>(
        stream: ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load orders.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(
                widget.customer
                    ? 'My orders and receipts'
                    : 'Customer preorders',
                style: Theme.of(context).textTheme.headlineSmall),
            if (orders.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24), child: Text('No orders found.')),
            for (final order in orders)
              Card(
                  child: ListTile(
                      title: Text(peso(order.total)),
                      subtitle: Text(
                          '${order.status} • ${order.deliveryMode} • ${stamp(order.createdAt)}'),
                      trailing: widget.customer || order.status != 'pending'
                          ? const Icon(Icons.receipt_long)
                          : FilledButton(
                              onPressed: busy ? null : () => confirm(order),
                              child: const Text('Confirm')),
                      onTap: () => showOrder(order))),
          ]);
        },
      );
}
