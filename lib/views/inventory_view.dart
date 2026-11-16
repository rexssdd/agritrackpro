import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import '../widgets/common.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/product_image_placeholder.dart';

class InventoryView extends StatefulWidget {
  final StoreRepository repo;
  final bool isOwner;
  final bool canEditProducts;
  const InventoryView(
      {super.key,
      required this.repo,
      required this.isOwner,
      this.canEditProducts = false});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  String search = '';
  bool lowStockOnly = false;
  Future<void> edit(Product? old) async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProductFormDialog(
            repo: widget.repo, product: old, canEditCost: widget.isOwner));
  }

  Future<void> adjust(Product p) async {
    final amount = TextEditingController(), reason = TextEditingController();
    bool add = true;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    title: Text('Adjust ${p.name}'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      SegementChoice(
                          add: add, onChanged: (v) => set(() => add = v)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantity')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: reason,
                          decoration: const InputDecoration(
                              labelText: 'Reason / supplier'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Save'))
                    ])));
    if (ok != true) return;
    try {
      final q = int.parse(amount.text);
      if (q <= 0) throw Exception('Quantity must be positive');
      await widget.repo.adjustStock(p, add ? q : -q, reason.text);
    } catch (e) {
      if (mounted) errorMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
      stream: widget.repo.watchProducts(),
      builder: (context, s) {
        if (s.hasError) return Center(child: Text('${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final products = s.data!
            .where((p) =>
                p.active &&
                (!lowStockOnly || p.stock <= p.reorderLevel) &&
                ('${p.name} ${p.category}')
                    .toLowerCase()
                    .contains(search.toLowerCase()))
            .toList();
        return Scaffold(
            floatingActionButton: widget.isOwner || widget.canEditProducts
                ? FloatingActionButton.extended(
                    onPressed: () => edit(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add product'))
                : null,
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Text('Inventory',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                  onChanged: (v) => setState(() => search = v),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search chemicals, fertilizers…')),
              const SizedBox(height: 12),
              FilterChip(
                  label: const Text('Needs replenishment'),
                  selected: lowStockOnly,
                  onSelected: (value) => setState(() => lowStockOnly = value)),
              ...products.map((p) => Card(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ListTile(
                          leading: ProductImagePlaceholder(
                              size: 52, imageBase64: p.imageBase64),
                          title: Text(p.name),
                          tileColor: p.stock <= p.reorderLevel
                              ? Colors.orange.withValues(alpha: 0.08)
                              : null,
                          subtitle: Text(
                              '${p.category} • ${peso(p.price)} / ${p.unit}\nStock: ${p.stock} • Reorder: ${p.reorderLevel}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                              onSelected: (v) =>
                                  v == 'edit' ? edit(p) : adjust(p),
                              itemBuilder: (ctx) => [
                                    if (widget.isOwner ||
                                        widget.canEditProducts)
                                      const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit product')),
                                    const PopupMenuItem(
                                        value: 'adjust',
                                        child: Text('Adjust stock'))
                                  ]))))),
              if (products.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No products found')))
            ]));
      });
}

class SegementChoice extends StatelessWidget {
  final bool add;
  final ValueChanged<bool> onChanged;
  const SegementChoice({super.key, required this.add, required this.onChanged});
  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(segments: const [
        ButtonSegment(value: true, label: Text('Restock')),
        ButtonSegment(value: false, label: Text('Deduct'))
      ], selected: {
        add
      }, onSelectionChanged: (v) => onChanged(v.first));
}
