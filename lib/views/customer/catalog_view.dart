import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image_placeholder.dart';

class CatalogView extends StatefulWidget {
  const CatalogView({super.key, required this.repo, this.guest = false});
  final StoreRepository repo;
  final bool guest;
  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  String search = '';
  bool inStockOnly = false;
  late final products = widget.repo.watchProducts();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
        stream: products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Unable to load catalog. Please try again later.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!
              .where((p) =>
                  p.active &&
                  (!inStockOnly || p.stock > 0) &&
                  '${p.name} ${p.category}'
                      .toLowerCase()
                      .contains(search.toLowerCase()))
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Agri Supply catalog',
                style: Theme.of(context).textTheme.headlineSmall),
            const Text(
                'Browse products and prices. Visit the store to purchase; availability may change.'),
            const SizedBox(height: 12),
            TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(
                    labelText: 'Search products or categories',
                    prefixIcon: Icon(Icons.search))),
            FilterChip(
                label: const Text('In stock only'),
                selected: inStockOnly,
                onSelected: (value) => setState(() => inStockOnly = value)),
            if (items.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No matching products.')),
            for (final p in items)
              Card(
                  child: ListTile(
                leading: ProductImagePlaceholder(
                    imageBase64: p.imageBase64, size: 56),
                title: Text(p.name),
                subtitle: Text(
                    '${p.category}\n${p.stock > 0 ? 'In stock' : 'Out of stock'}'),
                trailing: widget.guest
                    ? const Icon(Icons.lock_outline)
                    : Text('${peso(p.price)} / ${p.unit}'),
                isThreeLine: true,
                onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                          title: Text(p.name),
                          content: SingleChildScrollView(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                ProductImagePlaceholder(
                                    imageBase64: p.imageBase64, size: 160),
                                Text(p.description.isEmpty
                                    ? p.category
                                    : p.description),
                                Text('${peso(p.price)} / ${p.unit}'),
                                Text(p.stock > 0
                                    ? 'Available in store'
                                    : 'Currently out of stock'),
                              ])),
                          actions: [
                            if (widget.guest)
                              FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(content: Text('Sign in to continue with a preorder.')));
                                  },
                                  child: const Text('Sign in to preorder')),
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'))
                          ],
                        )),
              )),
          ]);
        },
      );
}
