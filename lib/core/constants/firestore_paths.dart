/// Single source of truth for collection names and storage folders.
abstract final class FirestorePaths {
  static const users = 'users';
  static const chats = 'chats';
  static const messages = 'messages';
  static const statuses = 'statuses';
  static const calls = 'calls';
  static const groupInvites = 'groupInvites';
  static const presence = 'presence';

  static String chat(String chatId) => '$chats/$chatId';
  static String chatMessages(String chatId) => '$chats/$chatId/$messages';
  static String scheduled(String uid) => '$users/$uid/scheduled';
}

abstract final class StoragePaths {
  static String avatar(String uid) => 'avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
  static String groupPhoto(String chatId) => 'groups/$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg';
  static String chatMedia(String chatId, String fileName) => 'chats/$chatId/$fileName';
  static String status(String uid, String fileName) => 'statuses/$uid/$fileName';
}
