import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum WallpaperKind { pattern, color, image }

/// A chat background: the default painted pattern, a solid colour, or a photo.
@immutable
class Wallpaper {
  const Wallpaper.pattern() : kind = WallpaperKind.pattern, color = null, imagePath = null;
  const Wallpaper.color(Color this.color) : kind = WallpaperKind.color, imagePath = null;
  const Wallpaper.image(String this.imagePath) : kind = WallpaperKind.image, color = null;

  final WallpaperKind kind;
  final Color? color;
  final String? imagePath;

  String encode() => switch (kind) {
    WallpaperKind.pattern => 'pattern',
    WallpaperKind.color => 'color:${color!.toARGB32()}',
    WallpaperKind.image => 'image:$imagePath',
  };

  static Wallpaper decode(String? s) {
    if (s == null || s == 'pattern') return const Wallpaper.pattern();
    if (s.startsWith('color:')) return Wallpaper.color(Color(int.tryParse(s.substring(6)) ?? 0xFFE8F3FA));
    if (s.startsWith('image:')) {
      final path = s.substring(6);
      return File(path).existsSync() ? Wallpaper.image(path) : const Wallpaper.pattern();
    }
    return const Wallpaper.pattern();
  }

  @override
  bool operator ==(Object other) => other is Wallpaper && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Wallpapers are a per-device preference (like WhatsApp): one default for
/// all chats plus optional per-chat overrides.
class WallpaperStore extends ChangeNotifier {
  WallpaperStore(this._prefs);
  final SharedPreferences _prefs;

  static const _globalKey = 'wallpaper.global';
  static String _chatKey(String chatId) => 'wallpaper.chat.$chatId';

  /// Background for [chatId]: its own override, else the global default.
  Wallpaper forChat(String? chatId) {
    final own = chatId == null ? null : _prefs.getString(_chatKey(chatId));
    return Wallpaper.decode(own ?? _prefs.getString(_globalKey));
  }

  Wallpaper get global => Wallpaper.decode(_prefs.getString(_globalKey));
  bool hasOverride(String chatId) => _prefs.containsKey(_chatKey(chatId));

  /// [chatId] null → applies to all chats (and clears no overrides).
  Future<void> set(Wallpaper w, {String? chatId}) async {
    await _prefs.setString(chatId == null ? _globalKey : _chatKey(chatId), w.encode());
    notifyListeners();
  }

  Future<void> clearOverride(String chatId) async {
    await _prefs.remove(_chatKey(chatId));
    notifyListeners();
  }

  /// Copies a picked photo into app storage so it survives gallery changes.
  Future<String> keepImage(File source) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/wallpapers');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final copy = await source.copy('${dir.path}/${const Uuid().v4()}.jpg');
    return copy.path;
  }
}
