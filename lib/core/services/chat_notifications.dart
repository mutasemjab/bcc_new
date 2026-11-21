import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

/// WhatsApp-style notifications: one notification per chat that collects its
/// messages ("Ahmad: hi / Ahmad: are you there?"), plus a summary when
/// several chats have unread messages.
///
/// Works from the main isolate (app open) and from the FCM background isolate
/// (app in background or closed), so all state lives in SharedPreferences.
abstract final class ChatNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _messagesChannel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'New chat messages',
    importance: Importance.high,
  );
  static const _callsChannel = AndroidNotificationChannel(
    'calls',
    'Calls',
    description: 'Incoming voice and video calls',
    importance: Importance.max,
  );

  static const _groupKey = 'bcc.messages';
  static const _summaryId = 0x0BCC;
  static const _storePrefix = 'notif.chat.';
  static const _maxPerChat = 8;
  static const _brand = Color(0xFF3A9AD9);

  /// Chat currently on screen — its messages are not notified.
  static String? openChatId;

  /// Call once per isolate. [onTap] receives the notification payload.
  static Future<void> init({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: onTap == null ? null : (r) => onTap(r.payload),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_messagesChannel);
    await android?.createNotificationChannel(_callsChannel);
    _initialized = true;
  }

  /// Payload of the notification that launched the app from "closed".
  static Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details!.notificationResponse?.payload;
  }

  static int _idFor(String chatId) => chatId.hashCode & 0x7FFFFFFF;

  /// Adds a message to its chat's notification (creating it if needed).
  static Future<void> showMessage({
    required String chatId,
    required String chatTitle,
    required String senderName,
    required String text,
    required bool isGroup,
    DateTime? time,
  }) async {
    if (chatId == openChatId) return;
    await init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // another isolate may have written

    final key = '$_storePrefix$chatId';
    final history = [
      ...(prefs.getStringList(key) ?? const <String>[]),
      jsonEncode({'s': senderName, 't': text, 'at': (time ?? DateTime.now()).millisecondsSinceEpoch}),
    ];
    final trimmed = history.length > _maxPerChat ? history.sublist(history.length - _maxPerChat) : history;
    await prefs.setStringList(key, trimmed);
    await prefs.setString('$_storePrefix$chatId.title', chatTitle);

    final messages = [
      for (final raw in trimmed)
        () {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          return Message(
            m['t'] as String,
            DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
            Person(name: m['s'] as String, key: m['s'] as String),
          );
        }(),
    ];

    final android = AndroidNotificationDetails(
      _messagesChannel.id,
      _messagesChannel.name,
      channelDescription: _messagesChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      icon: 'ic_notification',
      color: _brand,
      groupKey: _groupKey,
      number: trimmed.length,
      styleInformation: MessagingStyleInformation(
        const Person(name: 'You', key: 'me'),
        conversationTitle: isGroup ? chatTitle : null,
        groupConversation: isGroup,
        messages: messages,
      ),
    );
    final ios = DarwinNotificationDetails(
      threadIdentifier: chatId, // iOS stacks a chat's notifications together
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
      presentBadge: true,
    );

    await _plugin.show(
      id: _idFor(chatId),
      title: isGroup ? chatTitle : senderName,
      body: isGroup ? '$senderName: $text' : text,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: 'chat:$chatId',
    );
    if (defaultTargetPlatform == TargetPlatform.android) await _showSummary(prefs);
  }

  /// "5 messages from 2 chats" bundle header on Android.
  static Future<void> _showSummary(SharedPreferences prefs) async {
    final chats = prefs.getKeys().where((k) => k.startsWith(_storePrefix) && !k.endsWith('.title')).toList();
    if (chats.length < 2) return;
    var total = 0;
    final lines = <String>[];
    for (final k in chats) {
      final n = prefs.getStringList(k)?.length ?? 0;
      total += n;
      lines.add('${prefs.getString('$k.title') ?? 'Chat'}: $n new');
    }
    await _plugin.show(
      id: _summaryId,
      title: 'BCC Chat',
      body: '$total messages from ${chats.length} chats',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _messagesChannel.id,
          _messagesChannel.name,
          icon: 'ic_notification',
          color: _brand,
          groupKey: _groupKey,
          setAsGroupSummary: true,
          onlyAlertOnce: true,
          styleInformation: InboxStyleInformation(lines, summaryText: '$total messages from ${chats.length} chats'),
        ),
      ),
    );
  }

  /// Removes a chat's notification (called when the chat is opened).
  static Future<void> clearChat(String chatId) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.remove('$_storePrefix$chatId');
    await prefs.remove('$_storePrefix$chatId.title');
    await _plugin.cancel(id: _idFor(chatId));
    final left = prefs.getKeys().where((k) => k.startsWith(_storePrefix) && !k.endsWith('.title')).length;
    if (left < 2) await _plugin.cancel(id: _summaryId);
  }

  /// Simple one-off notification (calls, group invitations).
  static Future<void> showSimple({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool isCall = false,
  }) async {
    await init();
    final channel = isCall ? _callsChannel : _messagesChannel;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: channel.importance,
          priority: isCall ? Priority.max : Priority.high,
          category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.social,
          fullScreenIntent: isCall,
          timeoutAfter: isCall ? 45000 : null,
          icon: 'ic_notification',
          color: _brand,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true),
      ),
    );
  }

  static bool _tzReady = false;

  static Future<void> _initTimeZone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Dubai'));
    }
    _tzReady = true;
  }

  /// Reminder notification at [at] (e.g. for an appointment). Inexact by a
  /// few minutes on Android to save battery — no special alarm permission.
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!at.isAfter(DateTime.now())) return;
    await init();
    await _initTimeZone();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'appointments',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _messagesChannel.id,
          _messagesChannel.name,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: 'ic_notification',
          color: _brand,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true),
      ),
    );
  }

  static Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }
}
