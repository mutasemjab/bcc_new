import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

abstract final class Formatters {
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// "14:05", "Yesterday", "Mon", "12/03/26" — the chat list style.
  static String chatListTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    if (_sameDay(date, now)) return DateFormat.Hm().format(date);
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) return tr('Yesterday');
    if (now.difference(date).inDays < 7) return DateFormat.E().format(date);
    return DateFormat('dd/MM/yy').format(date);
  }

  static String messageTime(DateTime? date) => date == null ? '' : DateFormat.Hm().format(date);

  /// Header chip between message groups.
  static String dayHeader(DateTime date) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return tr('Today');
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) return tr('Yesterday');
    if (now.difference(date).inDays < 7) return DateFormat.EEEE().format(date);
    return DateFormat.yMMMMd().format(date);
  }

  static String lastSeen(DateTime? date) {
    if (date == null) return tr('last seen recently');
    final now = DateTime.now();
    if (_sameDay(date, now)) return tr('last seen today at {0}', [DateFormat.Hm().format(date)]);
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      return tr('last seen yesterday at {0}', [DateFormat.Hm().format(date)]);
    }
    return tr('last seen {0}', [DateFormat.MMMd().format(date)]);
  }

  static String relative(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return tr('Just now');
    if (diff.inMinutes < 60) return tr('{0}m ago', [diff.inMinutes]);
    if (diff.inHours < 24) return tr('{0}h ago', [diff.inHours]);
    return chatListTime(date);
  }

  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters_(1).toUpperCase();
    return (parts.first.characters_(1) + parts.last.characters_(1)).toUpperCase();
  }
}

extension on String {
  /// Grapheme-safe-ish prefix without pulling in package:characters.
  String characters_(int n) => runes.take(n).map(String.fromCharCode).join();
}
