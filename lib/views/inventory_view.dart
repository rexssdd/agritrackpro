import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import '../widgets/common.dart';

class InventoryView extends StatefulWidget {
  final StoreRepository repo;
  final bool isOwner;
  const InventoryView({super.key, required this.repo, required this.isOwner});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  String search = '';
  Future<void> edit(Product? old) async {
    final name = TextEditingController(text: old?.name ?? ''),
        category = TextEditingController(text: old?.category ?? 'Chemical'),
        unit = TextEditingController(text: old?.unit ?? 'bottle'),
        price = TextEditingController(text: old?.price.toString() ?? ''),
        cost = TextEditingController(text: old?.cost.toString() ?? ''),
        stock = TextEditingController(text: old?.stock.toString() ?? '0'),
        reorder =
            TextEditingController(text: old?.reorderLevel.toString() ?? '5');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(old == null ? 'Add product' : 'Edit product'),
                content: SizedBox(
                    width: 400,
                    child: Form(
                        key: form,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              for (final f in <(String, TextEditingController)>[
                                ('Name', name),
                                ('Category', category),
                                ('Unit', unit),
                                ('Selling price', price),
                                ('Purchase cost', cost),
                                if (old == null) ('Initial stock', stock),
                                ('Reorder level', reorder)
                              ])
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: TextFormField(
                                        controller: f.$2,
                                        keyboardType: [
                                          'Selling price',
                                          'Purchase cost',
                                          'Initial stock',
                                          'Reorder level'
                                        ].contains(f.$1)
                                            ? TextInputType.number
                                            : TextInputType.text,
                                        decoration:
                                            InputDecoration(labelText: f.$1),
                                        validator: (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Required'
                                                : null))
                            ])))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      child: const Text('Save'))
                ]));
    if (ok != true) return;
    try {
      final pr = double.parse(price.text),
          co = double.parse(cost.text),
          st = int.parse(stock.text),
          re = int.parse(reorder.text);
      await widget.repo.saveProduct(Product(
          id: old?.id ?? '',
          name: name.text.trim(),
          category: category.text.trim(),
          unit: unit.text.trim(),
          price: pr,
          cost: co,
          stock: st,
          reorderLevel: re));
    } catch (e) {
      if (mounted) errorMessage(context, e);
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
                ('${p.name} ${p.category}')
                    .toLowerCase()
                    .contains(search.toLowerCase()))
            .toList();
        return Scaffold(
            floatingActionButton: widget.isOwner
                ? FloatingActionButton.extended(
                    onPressed: () => edit(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Product'))
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
              ...products.map((p) => Card(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ListTile(
                          leading: CircleAvatar(
                              child: Icon(p.stock <= p.reorderLevel
                                  ? Icons.warning_amber
                                  : Icons.grass)),
                          title: Text(p.name),
                          subtitle: Text(
                              '${p.category} • ${peso(p.price)} / ${p.unit}\nStock: ${p.stock} • Reorder: ${p.reorderLevel}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                              onSelected: (v) =>
                                  v == 'edit' ? edit(p) : adjust(p),
                              itemBuilder: (ctx) => [
                                    if (widget.isOwner)
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
