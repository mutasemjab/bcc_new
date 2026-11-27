import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ar_strings.dart';

/// App language: follow the phone, or force Arabic / English.
enum AppLanguage { system, ar, en }

/// Language setting + the active locale. Arabic switches the whole app to
/// right-to-left (Material handles the mirroring).
class L10n extends ChangeNotifier {
  L10n(this._prefs) : _language = AppLanguage.values.asNameMap()[_prefs.getString(_key)] ?? AppLanguage.system {
    _apply();
  }

  final SharedPreferences _prefs;
  static const _key = 'app.language';

  AppLanguage _language;
  AppLanguage get language => _language;

  /// Used by [tr] — true when texts should be Arabic.
  static bool isArabic = false;

  Locale get locale => isArabic ? const Locale('ar') : const Locale('en');

  Future<void> setLanguage(AppLanguage l) async {
    _language = l;
    _apply();
    notifyListeners();
    await _prefs.setString(_key, l.name);
  }

  /// Re-evaluates when the phone's language changes (system mode).
  void systemLocaleChanged() {
    if (_language != AppLanguage.system) return;
    final was = isArabic;
    _apply();
    if (was != isArabic) notifyListeners();
  }

  void _apply() {
    isArabic = switch (_language) {
      AppLanguage.ar => true,
      AppLanguage.en => false,
      AppLanguage.system => PlatformDispatcher.instance.locale.languageCode == 'ar',
    };
    // Dates and times (month/day names) follow the app language too.
    Intl.defaultLocale = isArabic ? 'ar' : 'en';
  }
}

/// Translates a UI text. [key] is the English text; `{0}`, `{1}`… are filled
/// from [args] (names, numbers…). Falls back to English if missing.
String tr(String key, [List<Object?> args = const []]) {
  var s = L10n.isArabic ? (arStrings[key] ?? key) : key;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return s;
}
