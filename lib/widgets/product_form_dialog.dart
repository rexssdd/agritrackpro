import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import 'product_image_placeholder.dart';

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog(
      {super.key,
      required this.repo,
      this.product,
      this.chooseImage,
      this.canEditCost = true});
  final bool canEditCost;
  final StoreRepository repo;
  final Product? product;
  final Future<XFile?> Function()? chooseImage;
  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?.name ?? '');
  late final classification =
      TextEditingController(text: widget.product?.category ?? '');
  late final description =
      TextEditingController(text: widget.product?.description ?? '');
  late final price =
      TextEditingController(text: widget.product?.price.toString() ?? '');
  late final cost =
      TextEditingController(text: widget.product?.cost.toString() ?? '');
  late final quantity = TextEditingController(text: '0');
  late final unit = TextEditingController(text: widget.product?.unit ?? 'pcs');
  late final reorder = TextEditingController(
      text: widget.product?.reorderLevel.toString() ?? '5');
  bool saving = false;
  bool picking = false;
  late String imageBase64 = widget.product?.imageBase64 ?? '';
  String? error;

  Future<void> pickImage() async {
    if (saving || picking) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file = await (widget.chooseImage?.call() ??
          ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 60,
            requestFullMetadata: false,
          ));
      if (file == null) return;
      if (await file.length() > 120 * 1024) {
        throw const FormatException(
            'This photo is too large. Choose a smaller image (maximum 120 KB after resizing).');
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (mounted) setState(() => imageBase64 = base64Encode(bytes));
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Unable to open this photo. Allow photo access and choose a JPG or PNG image.');
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      classification,
      description,
      price,
      cost,
      quantity,
      unit,
      reorder
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController controller,
          {bool money = false, bool integer = false, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          enabled: !saving,
          maxLines: lines,
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : integer
                  ? TextInputType.number
                  : lines > 1
                      ? TextInputType.multiline
                      : TextInputType.text,
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixText: money ? '₱ ' : null,
              hintText: label == 'Classification'
                  ? 'e.g. Fertilizer, Pesticide, Seeds, Tools'
                  : null),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'Enter ${label.toLowerCase()}';
            if (money) {
              final number = double.tryParse(text);
              if (number == null || !number.isFinite || number < 0) {
                return 'Enter a valid non-negative price';
              }
            }
            if (integer) {
              final number = int.tryParse(text);
              if (number == null || number < 0) {
                return 'Enter a non-negative whole number';
              }
            }
            return null;
          },
        ),
      );

  Future<void> save() async {
    if (saving || picking || !form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = Product(
      id: widget.product?.id ?? '',
      name: name.text.trim(),
      category: classification.text.trim(),
      description: description.text.trim(),
      imageBase64: imageBase64,
      unit: unit.text.trim(),
      price: double.parse(price.text.trim()),
      cost: widget.canEditCost ? double.parse(cost.text.trim()) : 0,
      stock: widget.product?.stock ?? int.parse(quantity.text.trim()),
      reorderLevel: int.parse(reorder.text.trim()),
      active: widget.product?.active ?? true,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.product == null
            ? 'Preview new product'
            : 'Preview product changes'),
        content: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProductImagePlaceholder(imageBase64: draft.imageBase64, size: 140),
          const SizedBox(height: 12),
          Text(draft.name, style: Theme.of(context).textTheme.titleLarge),
          Text('Category: ${draft.category}'),
          Text(
              'Description: ${draft.description.isEmpty ? 'None' : draft.description}'),
          Text('Selling price: ₱${draft.price.toStringAsFixed(2)}'),
          if (widget.canEditCost)
            Text('Purchase cost: ₱${draft.cost.toStringAsFixed(2)}'),
          Text('Stock: ${draft.stock} ${draft.unit}'),
          Text('Reorder level: ${draft.reorderLevel}'),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back to edit')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm and save')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repo.saveProduct(draft);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Unable to save. Check your connection and product management access, then try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving && !picking,
        child: AlertDialog(
          title: Text(widget.product == null ? 'Add product' : 'Edit product'),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProductImagePlaceholder(
                              imageBase64: imageBase64, size: 120),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                              onPressed: saving || picking ? null : pickImage,
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined),
                              label: Text(picking
                                  ? 'Opening photos...'
                                  : imageBase64.isEmpty
                                      ? 'Add photo'
                                      : 'Change photo')),
                          if (imageBase64.isNotEmpty)
                            TextButton(
                                onPressed: saving || picking
                                    ? null
                                    : () => setState(() => imageBase64 = ''),
                                child: const Text('Remove photo')),
                          const Text(
                              'Optional product thumbnail. Saved when you tap Save product.'),
                          const SizedBox(height: 16),
                          field('Product name', name),
                          field('Classification', classification),
                          field('Description', description, lines: 3),
                          field('Selling price', price, money: true),
                          if (widget.canEditCost)
                            field('Purchase cost', cost, money: true),
                          if (!widget.canEditCost && widget.product == null)
                            const Text(
                                'The owner must set the purchase cost before this product can be sold.'),
                          if (widget.product == null)
                            field('Quantity', quantity, integer: true),
                          if (widget.product != null)
                            const Padding(
                                padding: EdgeInsets.only(bottom: 14),
                                child: Text(
                                    'Use Adjust stock to change quantity and record a reason.')),
                          field('Unit', unit),
                          field('Reorder level', reorder, integer: true),
                          if (error != null)
                            Semantics(
                                liveRegion: true,
                                child: Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          if (saving) const LinearProgressIndicator(),
                        ],
                      )))),
          actions: [
            TextButton(
                onPressed:
                    saving || picking ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: saving || picking ? null : save,
                child: Text(saving ? 'Saving...' : 'Save product'))
          ],
        ),
      );
}
