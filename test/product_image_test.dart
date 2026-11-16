import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:agritrack_pro/models/entities.dart';
import 'package:agritrack_pro/services/store_repository.dart';
import 'package:agritrack_pro/widgets/product_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class ImageRepo extends Fake implements StoreRepository {
  Product? saved;
  @override
  Future<void> saveProduct(Product product) async {
    saved = product;
  }
}

void main() {
  testWidgets('Product photo selection persists and removal clears the image',
      (tester) async {
    final bytes = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xff008800), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      final generated =
          (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
      image.dispose();
      picture.dispose();
      return generated;
    }))!;
    final repo = ImageRepo();
    Product product(String photo) => Product(
        id: 'p1',
        name: 'Seeds',
        category: 'Seeds',
        unit: 'bag',
        price: 10,
        cost: 5,
        stock: 2,
        reorderLevel: 1,
        description: 'Seeds for planting',
        imageBase64: photo);
    Future<void> open(Product old, Future<XFile?> Function() pick) async {
      await tester.pumpWidget(MaterialApp(
          key: UniqueKey(),
          home: Scaffold(
              body: ProductFormDialog(
                  key: UniqueKey(),
                  repo: repo,
                  product: old,
                  chooseImage: pick))));
      await tester.pumpAndSettle();
    }


    await open(
        product(''),
        () async =>
            XFile.fromData(bytes, name: 'photo.png', mimeType: 'image/png'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Add photo'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(repo.saved!.imageBase64, base64Encode(bytes));
    expect(repo.saved!.toMap()['imageBase64'], base64Encode(bytes));
    await open(product(base64Encode(bytes)), () async => null);
    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(repo.saved!.imageBase64, '');
    await open(
        product(''),
        () async =>
            XFile.fromData(Uint8List(120 * 1024 + 1), name: 'large.png'));
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This photo is too large'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
