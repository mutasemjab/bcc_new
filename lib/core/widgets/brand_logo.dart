import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The BCC Club Chat logo (assets/app_icon.png) on a white rounded card,
/// so it reads well on both light and dark backgrounds.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 88, this.showWordmark = false});
  final double size;
  final bool showWordmark;

  static const asset = 'assets/app_icon.png';

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
    );
    if (!showWordmark) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (r) => AppColors.brandGradient.createShader(r),
          child: Text('BCC Chat', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
