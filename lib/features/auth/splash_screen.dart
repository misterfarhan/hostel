import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.brand,
      body: Center(child: BrandMark(size: 84, light: true)),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.light = false});
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : AppColors.brand;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: light ? Colors.white : AppColors.brand, borderRadius: BorderRadius.circular(size * 0.28)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.location_on_rounded, size: size * 0.72, color: light ? AppColors.brand : Colors.white),
              Positioned(
                top: size * 0.2,
                child: Icon(Icons.home_rounded, size: size * 0.3, color: light ? Colors.white : AppColors.brand),
              ),
            ],
          ),
        ),
        SizedBox(height: size * 0.2),
        Text(
          'StayFinder',
          style: TextStyle(color: fg, fontSize: size * 0.36, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    );
  }
}
