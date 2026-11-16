import 'dart:convert';
import 'dart:ui' as ui;
import 'store_repository.dart';
import 'package:flutter/material.dart';
import '../models/entities.dart';

/// Explicitly invoked by an owner; never runs during startup or tests.
class DemoSeeder {
  static const products = [
    (
      'rice-seeds',
      'Certified Rice Seeds',
      'Seeds',
      'bag',
      1500.0,
      1150.0,
      40,
      'RICE',
      0xff388e3c
    ),
    (
      'corn-seeds',
      'Hybrid Corn Seeds',
      'Seeds',
      'bag',
      2200.0,
      1750.0,
      25,
      'CORN',
      0xfff9a825
    ),
    (
      'vegetable-seeds',
      'Mixed Vegetable Seeds',
      'Seeds',
      'pack',
      85.0,
      50.0,
      80,
      'SEEDS',
      0xff7b1fa2
    ),
    (
      'complete-fertilizer',
      'Complete Fertilizer 14-14-14',
      'Fertilizer',
      'bag',
      1650.0,
      1350.0,
      30,
      '14-14-14',
      0xff1565c0
    ),
    (
      'urea',
      'Urea Fertilizer 46-0-0',
      'Fertilizer',
      'bag',
      1450.0,
      1180.0,
      35,
      '46-0-0',
      0xff00838f
    ),
    (
      'organic-compost',
      'Organic Compost',
      'Fertilizer',
      'bag',
      350.0,
      220.0,
      50,
      'COMPOST',
      0xff6d4c41
    ),
    (
      'hand-trowel',
      'Garden Hand Trowel',
      'Tools',
      'pcs',
      180.0,
      110.0,
      20,
      'TROWEL',
      0xff546e7a
    ),
    (
      'watering-can',
      'Watering Can 5L',
      'Tools',
      'pcs',
      280.0,
      190.0,
      15,
      'WATER 5L',
      0xff0277bd
    ),
  ];
  static const expenses = [
    ('rent', 'Sample store monthly rent', 'Rent', 8000.0),
    ('electricity', 'Sample store electricity bill', 'Utilities', 1250.0),
    ('delivery', 'Sample supplier delivery charge', 'Delivery', 650.0),
    ('packaging', 'Sample packaging supplies', 'Operating', 450.0),
    ('maintenance', 'Sample shelf maintenance', 'Other', 300.0),
  ];

  /// Small, bundled-by-code illustrations: no external image host required.
  static Future<String> productImage(String label, int color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xfff1f5ee), BlendMode.src);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(30, 16, 132, 160), const Radius.circular(12)),
      Paint()..color = Color(color),
    );
    canvas.drawCircle(const Offset(96, 65), 24, Paint()..color = Colors.white);
    canvas.drawOval(
        const Rect.fromLTWH(83, 44, 14, 27), Paint()..color = Color(color));
    canvas.drawOval(
        const Rect.fromLTWH(97, 55, 14, 24), Paint()..color = Color(color));
    final text = TextPainter(
      text: TextSpan(
          text: label,
          style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 126);
    text.paint(canvas, Offset((192 - text.width) / 2, 112));
    text.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(192, 192);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final encoded = base64Encode(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      if (encoded.length > 163840) {
        throw StateError('Seed image exceeds product image limit');
      }
      return encoded;
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  static Future<int> seed(StoreRepository repo) async {
    final items = <Map<String, dynamic>>[];
    for (final p in products) {
      final data = Product(
        id: '',
        name: p.$2,
        category: p.$3,
        unit: p.$4,
        price: p.$5,
        cost: p.$6,
        stock: p.$7,
        reorderLevel: 10,
        description: 'Sample catalog item: ${p.$2}.',
        imageBase64: await productImage(p.$8, p.$9),
      ).toMap()
        ..remove('updatedAt');
      items.add({...data, 'id': 'demo-${p.$1}'});
    }
    final result = await repo.operate('seed', {
      'products': items,
      'expenses': expenses
          .map((e) => {
                'id': 'demo-${e.$1}',
                'description': e.$2,
                'category': e.$3,
                'amount': e.$4,
              })
          .toList(),
    });
    return (result['count'] as num).toInt();
  }
}
