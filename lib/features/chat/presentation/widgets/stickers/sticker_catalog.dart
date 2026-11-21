import 'package:flutter/material.dart';

/// A built-in sticker: a big emoji with an optional caption, drawn in code so
/// the app needs no image assets. The [id] is what gets stored in a message.
class StickerDef {
  const StickerDef(this.id, this.emoji, {this.caption, this.colors = const [Color(0xFF3A9AD9), Color(0xFF84C4EB)]});
  final String id;
  final String emoji;
  final String? caption;
  final List<Color> colors;
}

class StickerPack {
  const StickerPack(this.id, this.name, this.icon, this.stickers);
  final String id;
  final String name;
  final String icon;
  final List<StickerDef> stickers;
}

abstract final class StickerCatalog {
  static const _blue = [Color(0xFF2479B5), Color(0xFF84C4EB)];
  static const _pink = [Color(0xFFFF4D6D), Color(0xFFFF8FA3)];
  static const _gold = [Color(0xFFFF8A3D), Color(0xFFFFC94D)];
  static const _green = [Color(0xFF1B9E4B), Color(0xFF5CD68C)];
  static const _night = [Color(0xFF2B2B2D), Color(0xFF5A5A5C)];

  static const packs = <StickerPack>[
    StickerPack('ar', 'عربي', '💬', [
      StickerDef('ar/marhaba', '👋', caption: 'مرحبا', colors: _blue),
      StickerDef('ar/shukran', '🙏', caption: 'شكراً', colors: _green),
      StickerDef('ar/sabah', '☀️', caption: 'صباح الخير', colors: _gold),
      StickerDef('ar/masa', '🌙', caption: 'تصبح على خير', colors: _night),
      StickerDef('ar/hahaha', '😂', caption: 'ههههه', colors: _gold),
      StickerDef('ar/tamam', '👌', caption: 'تمام', colors: _blue),
      StickerDef('ar/mabrouk', '🎉', caption: 'مبروك', colors: _pink),
      StickerDef('ar/afia', '💪', caption: 'يعطيك العافية', colors: _green),
      StickerDef('ar/habibi', '❤️', caption: 'حبيبي', colors: _pink),
      StickerDef('ar/inshallah', '🤲', caption: 'إن شاء الله', colors: _blue),
      StickerDef('ar/yalla', '🏃', caption: 'يلا', colors: _gold),
      StickerDef('ar/wallah', '😳', caption: 'والله؟', colors: _night),
    ]),
    StickerPack('en', 'English', '🔤', [
      StickerDef('en/hello', '👋', caption: 'Hello!', colors: _blue),
      StickerDef('en/thanks', '🙏', caption: 'Thanks', colors: _green),
      StickerDef('en/lol', '🤣', caption: 'LOL', colors: _gold),
      StickerDef('en/ok', '👍', caption: 'OK', colors: _blue),
      StickerDef('en/love', '😍', caption: 'Love it', colors: _pink),
      StickerDef('en/congrats', '🥳', caption: 'Congrats!', colors: _pink),
      StickerDef('en/omg', '😱', caption: 'OMG', colors: _night),
      StickerDef('en/brb', '⏳', caption: 'BRB', colors: _night),
      StickerDef('en/cool', '😎', caption: 'Cool', colors: _blue),
      StickerDef('en/sorry', '🥺', caption: 'Sorry', colors: _pink),
      StickerDef('en/onmyway', '🚗', caption: 'On my way', colors: _gold),
      StickerDef('en/gn', '😴', caption: 'Good night', colors: _night),
    ]),
    StickerPack('fun', 'Fun', '🐱', [
      StickerDef('fun/cat', '😸'),
      StickerDef('fun/dog', '🐶'),
      StickerDef('fun/party', '🥳'),
      StickerDef('fun/fire', '🔥'),
      StickerDef('fun/heart', '💖'),
      StickerDef('fun/clap', '👏'),
      StickerDef('fun/think', '🤔'),
      StickerDef('fun/cry', '😭'),
      StickerDef('fun/angry', '😡'),
      StickerDef('fun/ghost', '👻'),
      StickerDef('fun/rocket', '🚀'),
      StickerDef('fun/coffee', '☕'),
      StickerDef('fun/100', '💯'),
      StickerDef('fun/star', '🤩'),
      StickerDef('fun/monkey', '🙈'),
      StickerDef('fun/unicorn', '🦄'),
    ]),
  ];

  static final Map<String, StickerDef> _byId = {
    for (final p in packs)
      for (final s in p.stickers) s.id: s,
  };

  static StickerDef? byId(String? id) => id == null ? null : _byId[id];
}

/// Renders a built-in sticker. White outline + soft shadow give the
/// classic "die-cut sticker" look on any wallpaper.
class StickerView extends StatelessWidget {
  const StickerView({super.key, required this.sticker, this.size = 150});
  final StickerDef sticker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = Text(
      sticker.emoji,
      style: TextStyle(fontSize: size * (sticker.caption == null ? 0.72 : 0.5), height: 1.1),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child:
            sticker.caption == null
                ? DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: size * 0.08)],
                    shape: BoxShape.circle,
                  ),
                  child: emoji,
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    emoji,
                    SizedBox(height: size * 0.02),
                    Transform.rotate(
                      angle: -0.06,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: size * 0.08, vertical: size * 0.03),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: sticker.colors),
                          borderRadius: BorderRadius.circular(size * 0.12),
                          border: Border.all(color: Colors.white, width: size * 0.025),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: size * 0.06,
                              offset: Offset(0, size * 0.02),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          child: Text(
                            sticker.caption!,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: size * 0.13,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
