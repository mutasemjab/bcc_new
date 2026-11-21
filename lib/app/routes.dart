/// Route paths. Keep in one place so features never hard-code strings.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const emailAuth = '/welcome/email';
  static const phoneAuth = '/welcome/phone';
  static const profileSetup = '/profile-setup';

  static const home = '/';
  static const newChat = '/new-chat';
  static const newGroup = '/new-group';
  static const editProfile = '/edit-profile';

  static String conversation(String chatId) => '/chat/$chatId';
  static String groupInfo(String chatId) => '/chat/$chatId/group-info';
  static String chatMedia(String chatId) => '/chat/$chatId/media';
  static String joinGroup(String chatId, String code) => '/join/$chatId/$code';
  static const wallpaper = '/wallpaper';
  static String userProfile(String uid) => '/user/$uid';

  static const statusText = '/status/text';
  static const statusImage = '/status/image';
  static String statusViewer(String userId) => '/status/view/$userId';

  static String call(String callId) => '/call/$callId';
  static String incomingCall(String callId) => '/incoming-call/$callId';
}
