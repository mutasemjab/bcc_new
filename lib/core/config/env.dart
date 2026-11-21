/// Compile-time configuration. Pass values with --dart-define, e.g.
///   flutter run --dart-define=AGORA_APP_ID=xxxxxxxx
abstract final class Env {
  static const agoraAppId = "b2a03090808b46ac8f072d9fddde28f7";

  /// Name of the callable Cloud Function that mints Agora RTC tokens.
  static const agoraTokenFunction = 'generateAgoraToken';

  static const appName = 'BCC Chat';

  /// Where invited friends download the app. Replace with the Google Play /
  /// App Store link once the app is published.
  static const downloadUrl = 'https://play.google.com/store/apps/details?id=com.bccchat.ammar';
}
