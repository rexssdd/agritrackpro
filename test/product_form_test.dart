import 'package:agritrack_pro/models/entities.dart';
import 'package:agritrack_pro/services/store_repository.dart';
import 'package:agritrack_pro/widgets/product_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ProductRepo extends Fake implements StoreRepository {
  Product? saved;
  bool fail = false;
  @override
  Future<void> saveProduct(Product product) async {
    if (fail) throw StateError('offline');
    saved = product;
  }
}

void main() {
  testWidgets('Product modal validates values and persists all product fields', (tester) async {
    final repo = ProductRepo();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductFormDialog(repo: repo))));
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    Future<void> fill(String label, String text) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
    }
    await fill('Product name', 'Organic fertilizer');
    await fill('Classification', 'Fertilizer');
    await fill('Description', 'For vegetables');
    await fill('Selling price', '250.50');
    await fill('Purchase cost', '190');
    await fill('Quantity', '-2');
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    expect(find.text('Enter a non-negative whole number'), findsOneWidget);
    await fill('Quantity', '12');
    repo.fail = true;
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to save.'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Organic fertilizer'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(repo.saved!.description, 'For vegetables');
    expect(repo.saved!.category, 'Fertilizer');
    expect(repo.saved!.stock, 12);
    expect(repo.saved!.price, 250.50);
    expect(repo.saved!.toMap()['description'], 'For vegetables');
  });
}
