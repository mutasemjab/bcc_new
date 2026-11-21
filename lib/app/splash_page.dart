import 'package:flutter/material.dart';

import '../core/widgets/brand_logo.dart';
import '../features/auth/presentation/widgets/auth_background.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, s, c) => Transform.scale(scale: s, child: c),
            child: const BrandLogo(size: 104, showWordmark: true),
          ),
        ),
      ),
    );
  }
}
