import 'dart:convert';
import 'package:flutter/material.dart';

class ProductImagePlaceholder extends StatelessWidget {
  const ProductImagePlaceholder(
      {super.key, this.size = 100, this.imageBase64 = ''});
  final double size;
  final String imageBase64;
  @override
  Widget build(BuildContext context) {
    if (imageBase64.isNotEmpty) {
      try {
        return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(imageBase64),
              width: size,
              height: size,
              fit: BoxFit.cover,
              semanticLabel: 'Product photo',
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => ProductImagePlaceholder(size: size),
            ));
      } on FormatException {
        return ProductImagePlaceholder(size: size);
      }
    }
    return Semantics(
      label: 'Product image placeholder',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Icon(Icons.image_outlined,
            size: size * .45,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
