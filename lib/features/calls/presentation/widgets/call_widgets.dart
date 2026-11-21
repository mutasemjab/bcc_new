import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/pressable.dart';

/// Round call control with label.
class CallControl extends StatelessWidget {
  const CallControl({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.danger = false,
    this.label,
    this.size = 62,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool danger;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg =
        danger
            ? AppColors.danger
            : active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.16);
    final fg = danger ? Colors.white : (active ? const Color(0xFF0B1324) : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: onTap,
          scale: 0.9,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow:
                  danger
                      ? [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                      : null,
            ),
            child: Icon(icon, color: fg, size: size * 0.42),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

/// Frosted panel holding the controls.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Avatar with expanding "ripple" rings — used while ringing / on voice calls.
class PulsingAvatar extends StatefulWidget {
  const PulsingAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 140,
    this.animate = true,
    this.isGroup = false,
  });
  final String name;
  final String? photoUrl;
  final double size;
  final bool animate;
  final bool isGroup;

  @override
  State<PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<PulsingAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(PulsingAvatar old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 1.9,
      height: s * 1.9,
      child: AnimatedBuilder(
        animation: _c,
        builder:
            (_, child) => Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Builder(
                    builder: (_) {
                      final t = (_c.value + i / 3) % 1.0;
                      return Opacity(
                        opacity: widget.animate ? (1 - t) * 0.5 : 0,
                        child: Container(
                          width: s + s * 0.9 * t,
                          height: s + s * 0.9 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                          ),
                        ),
                      );
                    },
                  ),
                child!,
              ],
            ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
          child: AppAvatar(name: widget.name, imageUrl: widget.photoUrl, size: s, isGroup: widget.isGroup),
        ),
      ),
    );
  }
}

/// Animated gradient backdrop for voice calls / incoming calls.
class CallBackdrop extends StatelessWidget {
  const CallBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2233), Color(0xFF15364F), Color(0xFF1E1F22)],
        ),
      ),
      child: child,
    );
  }
}
