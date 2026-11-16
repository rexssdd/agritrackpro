import 'dart:convert';
import 'dart:ui' as ui;
import 'package:agritrack_pro/services/demo_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Every seed product has a decodable thumbnail within the Firebase limit',
      () async {
    final images = <String>{};
    for (final product in DemoSeeder.products) {
      final encoded = await DemoSeeder.productImage(product.$8, product.$9);
      expect(encoded.length, lessThanOrEqualTo(163840));
      final codec = await ui.instantiateImageCodec(base64Decode(encoded));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 192);
      expect(frame.image.height, 192);
      frame.image.dispose();
      codec.dispose();
      images.add(encoded);
    }
    expect(images.length, DemoSeeder.products.length);
  });
}
