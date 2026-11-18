import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image_placeholder.dart';
import '../../widgets/agri_ui.dart';
import '../../config/theme.dart';

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

  Future<void> guestOrder(Product product) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final address = TextEditingController();
    final quantity = TextEditingController(text: '1');
    String? formError;
    void disposeFields() {
      email.dispose();
      password.dispose();
      address.dispose();
      quantity.dispose();
    }

    InputDecoration fieldDecoration(String label, IconData icon,
            {String? helper}) =>
        InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 2)),
        );
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
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
            Expanded(
                child: Text('Order ${product.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          content: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                if (formError != null) ...[
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(formError!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer))),
                          ])),
                  const SizedBox(height: 12),
                ],
                Text(
                    'Create an account so the owner can contact you about this order.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
                Card(
                    elevation: 0,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          ProductImagePlaceholder(
                              imageBase64: product.imageBase64, size: 58),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    '${peso(product.price)} / ${product.unit}'),
                                Text('${product.stock} available'),
                              ])),
                        ]))),
                const SizedBox(height: 14),
                Text('Contact and delivery',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                    controller: address,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: fieldDecoration(
                        'Delivery address', Icons.location_on_outlined)),
                const SizedBox(height: 14),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        fieldDecoration('Gmail address', Icons.email_outlined)),
                const SizedBox(height: 14),
                Text('Account details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: fieldDecoration(
                        'Account password', Icons.lock_outline,
                        helper: 'Use at least 6 characters')),
                const SizedBox(height: 14),
                TextField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration(
                        'Quantity', Icons.shopping_cart_outlined,
                        helper: 'Maximum ${product.stock}')),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton.icon(
                onPressed: () {
                  final parsedQuantity = int.tryParse(quantity.text.trim());
                  final message = address.text.trim().isEmpty
                      ? 'Enter your delivery address.'
                      : !email.text.trim().contains('@')
                          ? 'Enter a valid Gmail address.'
                          : password.text.length < 6
                              ? 'Your account password must have at least 6 characters.'
                              : parsedQuantity == null || parsedQuantity < 1
                                  ? 'Enter a quantity of at least 1.'
                                  : parsedQuantity > product.stock
                                      ? 'Quantity cannot be greater than the available stock (${product.stock}).'
                                      : null;
                  if (message != null) {
                    setDialog(() => formError = message);
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Create account and order')),
          ],
        ),
      ),
    );
    if (submit != true || !mounted) {
      disposeFields();
      return;
    }
    try {
      final q = int.tryParse(quantity.text.trim()) ?? 0;
      if (address.text.trim().isEmpty ||
          !email.text.trim().contains('@') ||
          password.text.length < 6 ||
          q < 1 ||
          q > product.stock) {
        throw const FormatException(
            'Enter a valid address, Gmail, password (6+ characters), and quantity.');
      }
      await widget.repo.auth.createUserWithEmailAndPassword(
          email: email.text.trim(), password: password.text);
      widget.repo.role = 'customer';
      await widget.repo.createCustomerOrder([CartLine(product, q)],
          deliveryMode: 'Pickup',
          paymentMethod: 'Cash',
          address: address.text,
          customerEmail: email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Account created and order sent to the owner.')));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.code == 'email-already-in-use'
                ? 'This Gmail already has an account. Sign in to continue.'
                : 'Unable to create account: ${e.message ?? e.code}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      disposeFields();
    }
  }

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
            const AgriHero(
                title: 'Farm supplies for every season',
                subtitle: 'Explore products for a better harvest',
                icon: Icons.grass),
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
            AgriSectionTitle('Products',
                action: Text('${items.length} available',
                    style: const TextStyle(
                        color: AgriTheme.green, fontWeight: FontWeight.w700))),
            if (items.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No matching products.')),
            for (final p in items)
              Card(
                  child: ListTile(
                leading: ProductImagePlaceholder(
                    imageBase64: p.imageBase64, size: 56),
                title: Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
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
                                    guestOrder(p);
                                  },
                                  child:
                                      const Text('Create account and order')),
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
