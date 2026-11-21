import 'dart:math';

abstract final class IdUtils {
  static final _rnd = Random.secure();
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  /// Unguessable code for join links (letters + digits, no "_").
  static String randomCode(int length) =>
      String.fromCharCodes(List.generate(length, (_) => _alphabet.codeUnitAt(_rnd.nextInt(_alphabet.length))));

  /// Anonymous display name, e.g. "Member #4821".
  static String anonymousAlias() => 'Member #${1000 + _rnd.nextInt(9000)}';

  /// Deterministic id for a 1:1 conversation so both users share one doc.
  static String directChatId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Firebase uids and auto-ids never contain "_", so only direct chats do.
  static bool isDirectChatId(String chatId) => chatId.contains('_');

  static String? peerFromChatId(String chatId, String me) {
    if (!isDirectChatId(chatId)) return null;
    final parts = chatId.split('_');
    return parts.first == me ? parts.last : parts.first;
  }

  /// Maps a Firebase uid to a stable positive 31-bit integer for Agora.
  /// (FNV-1a hash; collisions inside a single call are practically impossible.)
  static int agoraUid(String firebaseUid) {
    var hash = 0x811c9dc5;
    for (final unit in firebaseUid.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final value = hash & 0x7FFFFFFF;
    return value == 0 ? 1 : value;
  }
}
