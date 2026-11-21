import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shimmering placeholder used while real-time data loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.palette.surfaceHigh;
    final highlight = Color.lerp(base, Colors.white, context.isDark ? 0.08 : 0.6)!;
    return AnimatedBuilder(
      animation: _c,
      builder:
          (_, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback:
                (rect) => LinearGradient(
                  colors: [base, highlight, base],
                  stops: const [0.25, 0.5, 0.75],
                  begin: Alignment(-1 - 2 * (1 - _c.value) + 2 * _c.value, 0),
                  end: Alignment(1 + 2 * _c.value, 0),
                ).createShader(rect),
            child: child,
          ),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 10});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: context.palette.surfaceHigh, borderRadius: BorderRadius.circular(radius)),
  );
}

/// Skeleton list resembling chat rows.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key, this.count = 8});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder:
            (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const SkeletonBox(width: 56, height: 56, radius: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120 + (i % 3) * 30.0, height: 14),
                        const SizedBox(height: 10),
                        SkeletonBox(width: 180 + (i % 2) * 40.0, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
