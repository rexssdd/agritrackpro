import 'package:flutter/material.dart';
import '../../services/store_repository.dart';
import 'catalog_view.dart';

class GuestCatalogView extends StatelessWidget {
  const GuestCatalogView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Browse as guest')),
        body: CatalogView(repo: StoreRepository(), guest: true),
      );
}
