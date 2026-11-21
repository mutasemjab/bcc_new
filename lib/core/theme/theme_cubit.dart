import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds and persists the user's chosen theme mode.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  static ThemeMode _read(SharedPreferences prefs) {
    final index = prefs.getInt(_key);
    return index == null ? ThemeMode.dark : ThemeMode.values[index];
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(mode);
    await _prefs.setInt(_key, mode.index);
  }
}
