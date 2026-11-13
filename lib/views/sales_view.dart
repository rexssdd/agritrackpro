import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import '../widgets/common.dart';

class SalesView extends StatefulWidget {
  final StoreRepository repo;
  const SalesView({super.key, required this.repo});
  @override
  State<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<SalesView> {
  final cart = <String, CartLine>{};
  final customer = TextEditingController(), paid = TextEditingController();
  String method = 'Cash';
  bool saving = false;
  String search = '';
  @override
  void dispose() {
    customer.dispose();
    paid.dispose();
    super.dispose();
  }

  double get previewTotal =>
      cart.values.fold(0, (v, l) => v + l.product.price * l.quantity);
  Future<void> checkout() async {
    setState(() => saving = true);
    try {
      final id = await widget.repo.checkout(cart.values.toList(),
          method: method,
          amountPaid: double.parse(paid.text),
          customer: customer.text);
      if (!mounted) return;
      setState(() => cart.clear());
      paid.clear();
      customer.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment saved • Receipt ${id.substring(0, 8)}')));
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
      stream: widget.repo.watchProducts(),
      builder: (context, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final available = s.data!
            .where((p) =>
                p.active &&
                p.stock > 0 &&
                p.name.toLowerCase().contains(search.toLowerCase()))
            .toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('New sale',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Find a product'),
              onChanged: (v) => setState(() => search = v)),
          const SizedBox(height: 10),
          ...available.map((p) => Card(
              child: ListTile(
                  title: Text(p.name),
                  subtitle:
                      Text('${peso(p.price)} • ${p.stock} ${p.unit} available'),
                  trailing: IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFF166534)),
                      onPressed: () {
                        setState(() {
                          final l = cart[p.id];
                          if (l == null) {
                            cart[p.id] = CartLine(p);
                          } else if (l.quantity < p.stock) {
                            l.quantity++;
                          }
                        });
                      })))),
          const SizedBox(height: 16),
          Text('Cart', style: Theme.of(context).textTheme.titleLarge),
          if (cart.isEmpty)
            const Card(child: ListTile(title: Text('Tap + to add products'))),
          ...cart.values.map((l) => Card(
              child: ListTile(
                  title: Text(l.product.name),
                  subtitle: Text('${l.quantity} × ${peso(l.product.price)}'),
                  trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                            onPressed: () => setState(() {
                                  if (l.quantity <= 1) {
                                    cart.remove(l.product.id);
                                  } else {
                                    l.quantity--;
                                  }
                                }),
                            icon: const Icon(Icons.remove_circle_outline)),
                        Text('${l.quantity}'),
                        IconButton(
                            onPressed: () => setState(() {
                                  if (l.quantity < l.product.stock) {
                                    l.quantity++;
                                  }
                                }),
                            icon: const Icon(Icons.add_circle_outline))
                      ])))),
          const SizedBox(height: 10),
          Text('Total: ${peso(previewTotal)}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
              controller: customer,
              decoration:
                  const InputDecoration(labelText: 'Customer name (optional)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: ['Cash', 'GCash', 'Bank transfer']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => method = v!)),
          const SizedBox(height: 10),
          TextField(
              controller: paid,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Amount received (₱)')),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: cart.isEmpty || saving ? null : checkout,
              icon: const Icon(Icons.check_circle),
              label: Text(saving
                  ? 'Saving transaction…'
                  : 'Confirm payment & deduct stock')),
          const SizedBox(height: 24),
          Text('Recent payments',
              style: Theme.of(context).textTheme.titleLarge),
          StreamBuilder<List<Sale>>(
              stream: widget.repo.watchSales(),
              builder: (context, ss) {
                if (!ss.hasData) return const SizedBox();
                return Column(
                    children: ss.data!
                        .take(10)
                        .map((x) => Card(
                            child: ListTile(
                                title: Text(peso(x.total)),
                                subtitle:
                                    Text('${stamp(x.createdAt)} • ${x.method}'),
                                trailing: Text('${x.items.length} items'))))
                        .toList());
              })
        ]);
      });
}
