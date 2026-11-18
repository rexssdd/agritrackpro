import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'app_logo.dart';

class AgriHero extends StatelessWidget {
  const AgriHero(
      {super.key,
      required this.title,
      required this.subtitle,
      this.icon = Icons.eco_outlined,
      this.compact = false});
  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 20 : 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF07532A), Color(0xFF00843B)]),
        ),
        child: Stack(children: [
          Positioned(
              right: -18,
              top: -26,
              child: Icon(icon,
                  size: 128, color: Colors.white.withValues(alpha: .10))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const AppLogo(size: 40),
              const SizedBox(width: 10),
              const Text('AGRITRACK PRO',
                  style: TextStyle(
                      color: Color(0xFFCBF2D2),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      fontSize: 11)),
            ]),
            SizedBox(height: compact ? 16 : 22),
            Text(title,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 23 : 27,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(subtitle,
                style: const TextStyle(color: Color(0xFFE3F5E7), fontSize: 14)),
          ]),
        ]),
      );
}

class AgriSectionTitle extends StatelessWidget {
  const AgriSectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (action != null) action!,
      ]));
}

class AgriMetricCard extends StatelessWidget {
  const AgriMetricCard(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      this.color = AgriTheme.green,
      this.background = AgriTheme.paleGreen});
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: color,
              child: Icon(icon, size: 19, color: Colors.white)),
          const Spacer(),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 3),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: color))),
        ]),
      );
}
