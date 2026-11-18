import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/store_repository.dart';

class GcashSettingsView extends StatefulWidget {
  const GcashSettingsView({super.key, required this.repo});
  final StoreRepository repo;
  @override
  State<GcashSettingsView> createState() => _GcashSettingsViewState();
}

class _GcashSettingsViewState extends State<GcashSettingsView> {
  bool saving = false;
  String? selected;

  Future<void> chooseQr() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => selected = base64Encode(bytes));
  }

  Future<void> save() async {
    if (selected == null) return;
    setState(() => saving = true);
    try {
      await widget.repo.saveGcashQr(selected!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GCash QR saved for customers.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Unable to save QR: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget preview(String encoded) {
    final Uint8List bytes = base64Decode(encoded);
    return Image.memory(bytes,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text('Invalid QR image'));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: widget.repo.watchGcashSettings(),
        builder: (context, snapshot) {
          final current = snapshot.data?.data()?['imageBase64'] as String?;
          final image = selected ?? current;
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text('GCash payment QR',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Upload the store QR code customers should use. This is a mock payment flow until a GCash API is connected.'),
            const SizedBox(height: 20),
            if (image != null && image.isNotEmpty)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: preview(image))),
            OutlinedButton.icon(
                onPressed: saving ? null : chooseQr,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Choose QR image')),
            FilledButton.icon(
                onPressed: saving || selected == null ? null : save,
                icon: const Icon(Icons.save),
                label: Text(saving ? 'Saving...' : 'Save QR for customers')),
          ]);
        },
      );
}
