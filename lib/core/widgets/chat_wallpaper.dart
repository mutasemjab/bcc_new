import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/di.dart';
import '../services/wallpaper_store.dart';
import '../theme/app_colors.dart';

/// Chat background. Uses the user's chosen wallpaper for [chatId] (or the
/// global one); the default is a painted, theme-aware glyph pattern.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child, this.chatId, this.preview});
  final Widget child;
  final String? chatId;

  /// Forces a wallpaper (used by the picker's live preview).
  final Wallpaper? preview;

  @override
  Widget build(BuildContext context) {
    final store = sl<WallpaperStore>();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _build(context, preview ?? store.forChat(chatId)),
    );
  }

  Widget _build(BuildContext context, Wallpaper w) {
    final isDark = context.isDark;
    switch (w.kind) {
      case WallpaperKind.color:
        return ColoredBox(
          color: isDark ? Color.lerp(w.color, Colors.black, 0.55)! : w.color!,
          child: CustomPaint(painter: _PatternPainter(Colors.black.withValues(alpha: 0.05)), child: child),
        );
      case WallpaperKind.image:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(w.imagePath!), fit: BoxFit.cover),
            // Dim photos in dark mode so bubbles stay readable.
            if (isDark) ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            child,
          ],
        );
      case WallpaperKind.pattern:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors:
                  isDark
                      ? const [Color(0xFF0E0F11), Color(0xFF111316), Color(0xFF0D1114)]
                      : const [Color(0xFFF4F8FB), Color(0xFFEAF4FA), Color(0xFFF1F6F9)],
            ),
          ),
          child: CustomPaint(painter: _PatternPainter(context.palette.wallpaperDot), child: child),
        );
    }
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
    final rnd = math.Random(7);
    const cell = 56.0;
    for (double y = 0; y < size.height + cell; y += cell) {
      for (double x = 0; x < size.width + cell; x += cell) {
        final dx = x + rnd.nextDouble() * 20;
        final dy = y + rnd.nextDouble() * 20;
        switch (rnd.nextInt(4)) {
          case 0:
            canvas.drawCircle(Offset(dx, dy), 3.5, paint);
          case 1:
            final path =
                Path()
                  ..moveTo(dx - 5, dy)
                  ..quadraticBezierTo(dx, dy - 7, dx + 5, dy);
            canvas.drawPath(path, paint);
          case 2:
            canvas.drawLine(Offset(dx - 4, dy - 4), Offset(dx + 4, dy + 4), paint);
            canvas.drawLine(Offset(dx + 4, dy - 4), Offset(dx - 4, dy + 4), paint);
          default:
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(dx, dy), width: 9, height: 9),
                const Radius.circular(2.5),
              ),
              paint,
            );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.color != color;
}
