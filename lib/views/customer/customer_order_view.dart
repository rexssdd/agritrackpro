import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image_placeholder.dart';
import '../../widgets/agri_ui.dart';

class CustomerOrderView extends StatefulWidget {
  const CustomerOrderView({super.key, required this.repo});
  final StoreRepository repo;
  @override
  State<CustomerOrderView> createState() => _CustomerOrderViewState();
}

class _CustomerOrderViewState extends State<CustomerOrderView> {
  final quantities = <String, int>{};
  String search = '';
  String category = 'All';
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
    final total = items.fold<double>(
        0, (sum, line) => sum + line.product.price * line.quantity);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialog) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(children: [
            CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.shopping_bag_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Complete your order',
                    style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Review your delivery and payment details before placing your preorder.',
                    style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(height: 14),
            Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(Icons.receipt_long_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Order total')),
                      Text(peso(total),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ]))),
            const SizedBox(height: 14),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Fulfillment',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: delivery,
              decoration: const InputDecoration(
                  labelText: 'Delivery mode',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                  filled: true),
              items: const [
                DropdownMenuItem(value: 'Pickup', child: Text('Pickup')),
                DropdownMenuItem(
                    value: 'Cash on delivery', child: Text('Cash on delivery')),
              ],
              onChanged: (v) => setDialog(() => delivery = v!),
            ),
            const SizedBox(height: 14),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Payment',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: payment,
              decoration: const InputDecoration(
                  labelText: 'Payment method',
                  prefixIcon: Icon(Icons.payments_outlined),
                  filled: true),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'GCash', child: Text('GCash')),
              ],
              onChanged: (v) => setDialog(() => payment = v!),
            ),
            if (payment == 'GCash')
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder(
                    stream: widget.repo.watchGcashSettings(),
                    builder: (context, snapshot) {
                      final encoded =
                          snapshot.data?.data()?['imageBase64'] as String?;
                      if (encoded == null || encoded.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                              'The owner has not uploaded a GCash QR yet.'),
                        );
                      }
                      try {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(base64Decode(encoded),
                                  height: 160)),
                        );
                      } catch (_) {
                        return const Text('The store QR image is unavailable.');
                      }
                    },
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final mockReference =
                          'MOCK-GCASH-${DateTime.now().millisecondsSinceEpoch}';
                      final paid = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          title: Row(children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 10),
                            const Text('GCash payment'),
                          ]),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Card(
                                  elevation: 0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Icon(Icons.qr_code_2, size: 120))),
                              const SizedBox(height: 12),
                              Text('Amount to pay',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              Text(peso(total),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              const Text(
                                'Simulation only. No real GCash charge or API request is made.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Confirm payment')),
                          ],
                        ),
                      );
                      if (paid == true) {
                        setDialog(() => reference.text = mockReference);
                      }
                    },
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(reference.text.isEmpty
                        ? 'Open mock GCash checkout'
                        : 'GCash payment simulated'),
                  ),
                  if (reference.text.isNotEmpty)
                    Text('Reference: ${reference.text}',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            const SizedBox(height: 8),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Place preorder')),
          ],
        );
      }),
    );
    if (result != true || !mounted) {
      reference.dispose();
      return;
    }
    if (payment == 'GCash' && reference.text.trim().isEmpty) {
      reference.dispose();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the GCash reference to continue.')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Order $id was submitted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Unable to place order: $e')));
      }
    } finally {
      reference.dispose();
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
        stream: widget.repo.watchProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load products.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = <String>[
            'All',
            ...{
              for (final p in snapshot.data!)
                if (p.active) p.category
            }
          ];
          final products = snapshot.data!
              .where((p) =>
                  p.active &&
                  p.stock > 0 &&
                  (category == 'All' || p.category == category) &&
                  '${p.name} ${p.category}'
                      .toLowerCase()
                      .contains(search.toLowerCase()))
              .toList();
          final count = quantities.values.fold<int>(0, (a, b) => a + b);
          return Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AgriHero(
                  title: 'Shop farm essentials',
                  subtitle: 'Quality supplies for every growing season',
                  icon: Icons.grass,
                  compact: true),
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
            SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ChoiceChip(
                    label: Text(categories[index]),
                    selected: category == categories[index],
                    onSelected: (_) =>
                        setState(() => category = categories[index]),
                  ),
                )),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  const AgriSectionTitle('Products'),
                  for (final p in products)
                    Card(
                      child: ListTile(
                        leading: ProductImagePlaceholder(
                            imageBase64: p.imageBase64, size: 52),
                        title: Text(p.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle:
                            Text('${p.category}\n${peso(p.price)} / ${p.unit}'),
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
                        : () => placeOrder(snapshot.data!
                            .where((p) => p.active && p.stock > 0)
                            .toList()),
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: Text(submitting
                        ? 'Submitting…'
                        : 'Review cart ($count items)'),
                  ),
                ),
              ),
          ]);
        },
      );
}
