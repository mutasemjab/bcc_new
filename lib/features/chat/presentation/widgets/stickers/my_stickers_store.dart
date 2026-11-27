import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// The user's own stickers (images picked from the gallery), kept on this
/// device in the app's documents folder.
class MyStickersStore {
  MyStickersStore(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'my_stickers';
  static const maxStickers = 60;

  List<File> load() => (_prefs.getStringList(_key) ?? const []).map(File.new).where((f) => f.existsSync()).toList();

  /// Copies [source] into app storage and puts it first in the list.
  Future<List<File>> add(File source) async {
    final dir = Directory(tr('{0}/stickers', [(await getApplicationDocumentsDirectory()).path]));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final dot = source.path.lastIndexOf('.');
    final ext = dot < 0 ? tr('.png') : source.path.substring(dot).toLowerCase();
    final copy = await source.copy('${dir.path}/${const Uuid().v4()}$ext');
    final paths = [copy.path, ...load().map((f) => f.path)].take(maxStickers).toList();
    await _prefs.setStringList(_key, paths);
    return load();
  }

  Future<List<File>> remove(File file) async {
    final paths = load().map((f) => f.path).where((p) => p != file.path).toList();
    await _prefs.setStringList(_key, paths);
    try {
      await file.delete();
    } catch (_) {
      /* already gone */
    }
    return load();
  }
}
