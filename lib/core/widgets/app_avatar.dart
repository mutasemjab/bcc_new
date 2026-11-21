import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Circular avatar with network image, gradient-initials fallback and an
/// optional animated presence dot.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 52,
    this.isOnline = false,
    this.isGroup = false,
    this.heroTag,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool isOnline;
  final bool isGroup;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.identity(name);
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          imageUrl == null || imageUrl!.isEmpty
              ? _fallback()
              : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              ),
    );

    if (heroTag != null) avatar = Hero(tag: heroTag!, child: avatar);

    if (!isOnline) return avatar;
    final dot = size * 0.26;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: size * 0.02,
            bottom: size * 0.02,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: dot * 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Center(
    child:
        isGroup
            ? Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.5)
            : Text(
              Formatters.initials(name),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36),
            ),
  );
}
