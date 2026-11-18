import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import '../widgets/common.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/product_image_placeholder.dart';
import '../widgets/agri_ui.dart';
import '../config/theme.dart';

class InventoryView extends StatefulWidget {
  final StoreRepository repo;
  final bool isOwner;
  final bool canEditProducts;
  final bool canAdjustStock;
  const InventoryView(
      {super.key,
      required this.repo,
      required this.isOwner,
      this.canEditProducts = false,
      this.canAdjustStock = true});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  String search = '';
  String stockFilter = 'All';
  Future<void> edit(Product? old) async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProductFormDialog(
            repo: widget.repo, product: old, canEditCost: widget.isOwner));
  }

  Future<void> archive(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive product?'),
        content: Text(
            '${product.name} will no longer appear in the shop or sales checkout.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repo.saveProduct(Product(
        id: product.id,
        name: product.name,
        category: product.category,
        unit: product.unit,
        price: product.price,
        cost: product.cost,
        stock: product.stock,
        reorderLevel: product.reorderLevel,
        description: product.description,
        imageBase64: product.imageBase64,
        active: false,
      ));
    } catch (error) {
      if (mounted) errorMessage(context, error);
    }
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
    if (ok != true || !mounted) return;
    try {
      final q = int.parse(amount.text);
      if (q <= 0) throw Exception('Quantity must be positive');
      final delta = add ? q : -q;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Preview stock adjustment'),
                content: Text(
                    '${add ? 'Add' : 'Deduct'} $q ${p.unit} for ${p.name}\n\nReason: ${reason.text.trim()}\nStock after change: ${p.stock + delta}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Back to edit')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirm adjustment')),
                ],
              ));
      if (confirmed == true) {
        await widget.repo.adjustStock(p, delta, reason.text);
      }
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
                (stockFilter == 'All' ||
                    (stockFilter == 'Low stock' &&
                        p.stock > 0 &&
                        p.stock <= p.reorderLevel) ||
                    (stockFilter == 'Out of stock' && p.stock == 0)) &&
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
              const AgriHero(
                  title: 'Inventory',
                  subtitle: 'Keep every product and stock level in view',
                  icon: Icons.inventory_2_outlined,
                  compact: true),
              const SizedBox(height: 12),
              TextField(
                  onChanged: (v) => setState(() => search = v),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search chemicals, fertilizers…')),
              const SizedBox(height: 12),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final filter in const [
                      'All',
                      'Low stock',
                      'Out of stock'
                    ]) ...[
                      ChoiceChip(
                          label: Text(filter),
                          selected: stockFilter == filter,
                          onSelected: (_) =>
                              setState(() => stockFilter = filter)),
                      const SizedBox(width: 8),
                    ],
                  ])),
              AgriSectionTitle(
                  stockFilter == 'All' ? 'All products' : stockFilter),
              ...products.map((p) => Card(
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ListTile(
                          leading: ProductImagePlaceholder(
                              size: 52, imageBase64: p.imageBase64),
                          title: Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          tileColor: p.stock <= p.reorderLevel
                              ? Colors.orange.withValues(alpha: 0.08)
                              : null,
                          subtitle: Text(
                              '${p.category}  •  ${peso(p.price)} / ${p.unit}\n${p.stock == 0 ? 'Out of stock' : p.stock <= p.reorderLevel ? 'Low stock' : 'In stock'}: ${p.stock} ${p.unit}  •  Reorder at ${p.reorderLevel}',
                              style: TextStyle(
                                  color: p.stock <= p.reorderLevel
                                      ? const Color(0xFFA66000)
                                      : AgriTheme.ink)),
                          isThreeLine: true,
                          trailing: widget.isOwner ||
                                  widget.canEditProducts ||
                                  widget.canAdjustStock
                              ? PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') edit(p);
                                    if (v == 'adjust') adjust(p);
                                    if (v == 'archive') archive(p);
                                  },
                                  itemBuilder: (ctx) => [
                                        if (widget.isOwner ||
                                            widget.canEditProducts)
                                          const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit product')),
                                        if (widget.canAdjustStock)
                                          const PopupMenuItem(
                                              value: 'adjust',
                                              child: Text('Adjust stock')),
                                        if (widget.isOwner ||
                                            widget.canEditProducts)
                                          const PopupMenuItem(
                                              value: 'archive',
                                              child: Text('Archive product')),
                                      ])
                              : const Icon(Icons.chevron_right))))),
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
