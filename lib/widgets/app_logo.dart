import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Replace assets/images/agritrack_logo.svg to change the application branding.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 84});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/images/agritrack_logo.svg',
        width: size,
        height: size,
        semanticsLabel: 'AgriTrack Pro logo',
      );
}
