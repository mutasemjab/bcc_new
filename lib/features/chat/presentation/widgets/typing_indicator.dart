import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three bouncing dots.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.color, this.size = 5});
  final Color color;
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder:
          (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_c.value - i * 0.18) % 1.0;
              final y = math.sin(t * math.pi * 2).clamp(0.0, 1.0) * widget.size * 0.8;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
                transform: Matrix4.translationValues(0, -y, 0),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              );
            }),
          ),
    );
  }
}

/// "typing…" label with dots, used in the app bar and chat list.
class TypingLabel extends StatelessWidget {
  const TypingLabel({super.key, required this.text, required this.color, this.fontSize = 13});
  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 4),
        TypingDots(color: color, size: 4),
      ],
    );
  }
}
