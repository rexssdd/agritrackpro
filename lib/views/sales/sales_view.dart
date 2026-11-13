import 'package:flutter/material.dart';
import '../../services/store_service.dart';
import '../../utils/formatters.dart';

class SalesView extends StatefulWidget {
  const SalesView({super.key});
  @override
  State<SalesView> createState() => _SalesViewState();
}
class _SalesViewState extends State<SalesView> {
  String? selectedProductId;
  String paymentMethod = 'Cash';
  final quantityController = TextEditingController(text: '1');
  @override
  void dispose() { quantityController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final store = StoreService.instance;
    final product = store.products.where((p) => p.id == selectedProductId).firstOrNull;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Record New Sale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: selectedProductId, decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
        items: store.products.where((p) => p.stock > 0).map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.stock} left)'))).toList(),
        onChanged: (v) => setState(() => selectedProductId = v)),
      const SizedBox(height: 12),
      TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: paymentMethod, decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
        items: ['Cash', 'GCash'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setState(() => paymentMethod = v ?? 'Cash')),
      const SizedBox(height: 12),
      if (product != null) Text('Unit Price: ${peso(product.sellingPrice)}'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: product == null ? null : () {
        try {
          store.recordSale(product, int.parse(quantityController.text), paymentMethod);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale recorded; stock updated')));
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check quantity and available stock')));
        }
      }, icon: const Icon(Icons.check_circle_outline), label: const Text('Confirm Payment')),
      const SizedBox(height: 20),
      const Text('Recent Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...store.sales.reversed.map((s) => ListTile(title: Text(s.productName), subtitle: Text('${s.quantity} item(s) • ${s.paymentMethod}'), trailing: Text(peso(s.total)))),
    ]);
  }
}
