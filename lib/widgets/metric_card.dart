import 'package:flutter/material.dart';
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const MetricCard({super.key, required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.green.shade700), const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    )),
  );
}
