import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'chat_notifications.dart';

/// Turns a push payload into a local notification. Shared by the background
/// handler (app in background / closed) and any foreground use.
///
/// Android pushes are data-only so the app itself builds a grouped,
/// WhatsApp-style notification per chat. iOS pushes carry an APNs alert that
/// the system shows (grouped by thread-id), so iOS never reaches here for them.
Future<void> showNotificationFor(RemoteMessage message) async {
  final d = message.data;
  switch (d['type']) {
    case 'message':
      final chatId = d['chatId'] as String?;
      if (chatId == null) return;
      await ChatNotifications.showMessage(
        chatId: chatId,
        chatTitle: (d['chatTitle'] as String?) ?? 'BCC Chat',
        senderName: (d['sender'] as String?) ?? 'New message',
        text: (d['body'] as String?) ?? '',
        isGroup: d['isGroup'] == 'true',
        time: DateTime.tryParse((d['sentAt'] as String?) ?? ''),
      );
    case 'call':
      final callId = d['callId'] as String? ?? '';
      await ChatNotifications.showSimple(
        id: callId.hashCode & 0x7FFFFFFF,
        title: (d['title'] as String?) ?? 'Incoming call',
        body: (d['body'] as String?) ?? 'Incoming call',
        payload: 'call:$callId',
        isCall: true,
      );
    case 'group_invite':
      final chatId = d['chatId'] as String? ?? '';
      await ChatNotifications.showSimple(
        id: ('invite$chatId').hashCode & 0x7FFFFFFF,
        title: (d['title'] as String?) ?? 'Group invitation',
        body: (d['body'] as String?) ?? 'You were invited to a group',
        payload: 'invite:$chatId',
      );
  }
}

/// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // A message that already has a system notification (iOS) needs nothing.
  if (message.notification != null) return;
  await showNotificationFor(message);
}

/// Push-notification wiring (permission + token lifecycle).
class PushService {
  PushService(this._messaging);
  final FirebaseMessaging _messaging;

  Future<String?> requestPermissionAndGetToken() async {
    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
      // While the app is open, chat notifications come from the live
      // Firestore listener (see ForegroundNotifier), not from the push.
      await _messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
      return await _messaging.getToken();
    } catch (_) {
      // Simulators without APNs, missing Play Services, etc.
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Pushes received while the app is in the foreground.
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// Messages that opened the app from background/terminated state.
  Stream<RemoteMessage> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp;
  Future<RemoteMessage?> initialMessage() => _messaging.getInitialMessage();
}
