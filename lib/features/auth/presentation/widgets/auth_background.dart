import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Slowly drifting, blurred gradient orbs behind the auth screens.
class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key, required this.child});
  final Widget child;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final alpha = context.isDark ? 0.55 : 0.35;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: context.theme.scaffoldBackgroundColor)),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value * 2 * math.pi;
            return Stack(
              children: [
                _orb(
                  Offset(size.width * (0.75 + 0.1 * math.sin(t)), size.height * (0.12 + 0.05 * math.cos(t))),
                  size.width * 0.8,
                  AppColors.primary.withValues(alpha: alpha),
                ),
                _orb(
                  Offset(size.width * (0.1 + 0.08 * math.cos(t)), size.height * (0.35 + 0.06 * math.sin(t))),
                  size.width * 0.7,
                  AppColors.accent.withValues(alpha: alpha * 0.8),
                ),
                _orb(
                  Offset(size.width * (0.6 + 0.1 * math.sin(t + 1)), size.height * (0.85 + 0.04 * math.cos(t))),
                  size.width * 0.6,
                  AppColors.violet.withValues(alpha: alpha * 0.7),
                ),
              ],
            );
          },
        ),
        Positioned.fill(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: const SizedBox.expand()),
        ),
        widget.child,
      ],
    );
  }

  Widget _orb(Offset center, double diameter, Color color) => Positioned(
    left: center.dx - diameter / 2,
    top: center.dy - diameter / 2,
    child: Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

/// Frosted card used for forms on top of [AuthBackground].
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surface.withValues(alpha: context.isDark ? 0.55 : 0.75),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: context.isDark ? 0.08 : 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}
