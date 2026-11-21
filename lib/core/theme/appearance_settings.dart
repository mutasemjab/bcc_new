import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A font the user can pick (Google Fonts family + a sample label).
class AppFont {
  const AppFont(this.family, this.label);
  final String family;
  final String label;
}

/// Font family and text size for the whole app (Settings → Font).
class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings(this._prefs)
    : _font = _prefs.getString(_fontKey) ?? fonts.first.family,
      _scale = _prefs.getDouble(_scaleKey) ?? 1.0;

  final SharedPreferences _prefs;
  static const _fontKey = 'appearance.font';
  static const _scaleKey = 'appearance.scale';

  static const fonts = <AppFont>[
    AppFont('Plus Jakarta Sans', 'Default'),
    AppFont('Cairo', 'Cairo — القاهرة'),
    AppFont('Tajawal', 'Tajawal — تجوال'),
    AppFont('Almarai', 'Almarai — المراعي'),
    AppFont('Noto Kufi Arabic', 'Noto Kufi — كوفي'),
    AppFont('Amiri', 'Amiri — أميري'),
    AppFont('Roboto', 'Roboto'),
    AppFont('Poppins', 'Poppins'),
  ];

  static const sizes = <(double, String)>[(0.9, 'Small'), (1.0, 'Medium'), (1.15, 'Large'), (1.3, 'Extra large')];

  String _font;
  double _scale;
  String get font => _font;
  double get scale => _scale;

  Future<void> setFont(String family) async {
    _font = family;
    notifyListeners();
    await _prefs.setString(_fontKey, family);
  }

  Future<void> setScale(double scale) async {
    _scale = scale;
    notifyListeners();
    await _prefs.setDouble(_scaleKey, scale);
  }
}
