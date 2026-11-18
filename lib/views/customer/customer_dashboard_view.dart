import 'package:flutter/material.dart';
import '../../models/entities.dart';
import '../../services/store_repository.dart';
import '../../widgets/agri_ui.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image_placeholder.dart';

class CustomerDashboardView extends StatefulWidget {
  const CustomerDashboardView(
      {super.key,
      required this.repo,
      required this.onShop,
      required this.onOrders});
  final StoreRepository repo;
  final VoidCallback onShop;
  final VoidCallback onOrders;

  @override
  State<CustomerDashboardView> createState() => _CustomerDashboardViewState();
}

class _CustomerDashboardViewState extends State<CustomerDashboardView> {
  String search = '';
  String category = 'All';

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (value) => setState(() => search = value),
            decoration: const InputDecoration(
                hintText: 'Search farm products',
                prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF00672E),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Farm supplies\nfor better yield',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                          onPressed: widget.onShop,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Shop now')),
                    ])),
                const Icon(Icons.grass, color: Color(0xFFADE6A6), size: 80),
              ]),
            ),
          ),
          const AgriSectionTitle('Explore categories'),
          SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _category('All', Icons.apps),
                  _category('Fertilizer', Icons.eco_outlined),
                  _category('Insecticide', Icons.bug_report_outlined),
                  _category('Herbicide', Icons.grass_outlined),
                  _category('Fungicide', Icons.spa_outlined),
                ],
              )),
          AgriSectionTitle('Featured products',
              action: TextButton(
                  onPressed: widget.onShop, child: const Text('See all'))),
          StreamBuilder<List<Product>>(
            stream: widget.repo.watchProducts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Card(
                    child: ListTile(title: Text('Unable to load products')));
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final products = snapshot.data!
                  .where((product) =>
                      product.active &&
                      product.stock > 0 &&
                      (category == 'All' ||
                          product.category.toLowerCase() ==
                              category.toLowerCase()) &&
                      '${product.name} ${product.category}'
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                  .take(4)
                  .toList();
              if (products.isEmpty) {
                return const Card(
                    child: ListTile(title: Text('No matching products')));
              }
              return LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: constraints.maxWidth > 550 ? 3 : 2,
                            mainAxisExtent: 280,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return Card(
                              child: InkWell(
                            onTap: widget.onShop,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                      child: ProductImagePlaceholder(
                                          imageBase64: product.imageBase64,
                                          size: 82)),
                                  const SizedBox(height: 7),
                                  Text(product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(product.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const Spacer(),
                                  Text(peso(product.price),
                                      style: const TextStyle(
                                          color: Color(0xFF00672E),
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                      '${product.stock} ${product.unit} available',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                          onPressed: widget.onShop,
                                          child: const Text('View in shop'))),
                                ],
                              ),
                            ),
                          ));
                        },
                      ));
            },
          ),
          const AgriSectionTitle('Recent orders'),
          StreamBuilder<List<CustomerOrder>>(
            stream: widget.repo.watchCustomerOrders(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Card(
                    child: ListTile(title: Text('Unable to load orders')));
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              if (snapshot.data!.isEmpty) {
                return Card(
                    child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: const Text('No orders yet'),
                        subtitle:
                            const Text('Your purchases will appear here.'),
                        onTap: widget.onShop));
              }
              return Column(children: [
                for (final order in snapshot.data!.take(3))
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(peso(order.total)),
                          subtitle: Text(order.status),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOrders)),
                TextButton(
                    onPressed: widget.onOrders,
                    child: const Text('View all orders')),
              ]);
            },
          ),
        ],
      );

  Widget _category(String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () => setState(() => category = label),
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
              width: 76,
              child: Column(children: [
                CircleAvatar(
                    backgroundColor: category == label
                        ? const Color(0xFF00672E)
                        : const Color(0xFFE8F5E9),
                    child: Icon(icon,
                        color: category == label
                            ? Colors.white
                            : const Color(0xFF00672E))),
                const SizedBox(height: 5),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
        ),
      );
}
