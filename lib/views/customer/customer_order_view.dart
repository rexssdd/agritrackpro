import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image_placeholder.dart';

class CustomerOrderView extends StatefulWidget {
  const CustomerOrderView({super.key, required this.repo});
  final StoreRepository repo;
  @override
  State<CustomerOrderView> createState() => _CustomerOrderViewState();
}

class _CustomerOrderViewState extends State<CustomerOrderView> {
  final quantities = <String, int>{};
  String search = '';
  bool submitting = false;

  Future<void> placeOrder(List<Product> products) async {
    final items = products
        .where((p) => (quantities[p.id] ?? 0) > 0)
        .map((p) => CartLine(p, quantities[p.id]!))
        .toList();
    if (items.isEmpty) return;
    String delivery = 'Pickup';
    String payment = 'Cash';
    final reference = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialog) {
        return AlertDialog(
          title: const Text('Confirm preorder'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: delivery,
              decoration: const InputDecoration(labelText: 'Delivery mode'),
              items: const [
                DropdownMenuItem(value: 'Pickup', child: Text('Pickup')),
                DropdownMenuItem(value: 'Cash on delivery', child: Text('Cash on delivery')),
              ],
              onChanged: (v) => setDialog(() => delivery = v!),
            ),
            DropdownButtonFormField<String>(
              value: payment,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'GCash', child: Text('GCash')),
              ],
              onChanged: (v) => setDialog(() => payment = v!),
            ),
            if (payment == 'GCash')
              TextField(
                controller: reference,
                decoration: const InputDecoration(labelText: 'GCash reference'),
              ),
            const SizedBox(height: 8),
            Text('Total: ${peso(items.fold<double>(0, (s, l) => s + l.product.price * l.quantity))}'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Place order')),
          ],
        );
      }),
    );
    if (result != true || !mounted) { reference.dispose(); return; }
    if (payment == 'GCash' && reference.text.trim().isEmpty) {
      reference.dispose();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the GCash reference to continue.')));
      return;
    }
    setState(() => submitting = true);
    try {
      final id = await widget.repo.createCustomerOrder(items,
          deliveryMode: delivery,
          paymentMethod: payment,
          paymentReference: reference.text.trim());
      if (mounted) {
        setState(() => quantities.clear());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order $id was submitted.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to place order: $e')));
    } finally {
      reference.dispose();
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
        stream: widget.repo.watchProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Unable to load products.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!.where((p) => p.active && p.stock > 0 && '${p.name} ${p.category}'.toLowerCase().contains(search.toLowerCase())).toList();
          final count = quantities.values.fold<int>(0, (a, b) => a + b);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Agri Supply catalog',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                    labelText: 'Search available products',
                    prefixIcon: Icon(Icons.search)),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final p in products)
                    Card(
                      child: ListTile(
                        leading: ProductImagePlaceholder(
                            imageBase64: p.imageBase64, size: 52),
                        title: Text(p.name),
                        subtitle: Text(
                            '${p.category}\n${peso(p.price)} / ${p.unit}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                onPressed: (quantities[p.id] ?? 0) == 0
                                    ? null
                                    : () => setState(() => quantities[p.id] =
                                        quantities[p.id]! - 1),
                                icon: const Icon(Icons.remove)),
                            Text('${quantities[p.id] ?? 0}'),
                            IconButton(
                                onPressed: (quantities[p.id] ?? 0) >= p.stock
                                    ? null
                                    : () => setState(() => quantities[p.id] =
                                        (quantities[p.id] ?? 0) + 1),
                                icon: const Icon(Icons.add)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : () => placeOrder(products),
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: Text(submitting
                        ? 'Submitting…'
                        : 'Continue to order ($count items)'),
                  ),
                ),
              ),
          ]);
        },
      );
}
