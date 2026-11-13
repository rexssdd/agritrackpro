import 'package:flutter/material.dart';
import '../../services/store_service.dart';
import '../../utils/formatters.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}
class _InventoryViewState extends State<InventoryView> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final products = StoreService.instance.products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products', border: OutlineInputBorder()), onChanged: (v) => setState(() => query = v)),
      const SizedBox(height: 12),
      ...products.map((p) => Card(child: ListTile(
        title: Text(p.name), subtitle: Text('${p.category} • ${p.stockStatus} • Stock: ${p.stock}'),
        trailing: Text(peso(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
      ))),
    ]);
  }
}
