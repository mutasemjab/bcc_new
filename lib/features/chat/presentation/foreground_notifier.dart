import 'package:flutter/widgets.dart';

import '../../../core/services/chat_notifications.dart';
import 'bloc/chat_list/chat_list_bloc.dart';

/// Shows chat notifications while the app is open, straight from the live
/// chat list — so they appear instantly and without any server push. Chats
/// that are muted, blocked or currently on screen are skipped.
///
/// When the app is in the background or closed, the push handler takes over
/// (see push_service.dart), so the two never notify the same message.
class ForegroundNotifier {
  final _lastSeen = <String, String>{};
  bool _primed = false;

  void reset() {
    _lastSeen.clear();
    _primed = false;
  }

  void onChats(ChatListState state, {Set<String> blocked = const {}}) {
    if (state.uid.isEmpty) return;
    final resumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    for (final chat in state.chats) {
      final last = chat.lastMessage;
      if (last == null) continue;
      final previous = _lastSeen[chat.id];
      _lastSeen[chat.id] = last.id;
      // First snapshot only records what already exists.
      if (!_primed || previous == last.id) continue;
      if (!resumed) continue;
      if (last.senderId == state.uid) continue;
      if (chat.isMutedFor(state.uid)) continue;
      if (!chat.isGroup && blocked.contains(chat.peerId(state.uid))) continue;
      if (last.preview.isEmpty) continue;

      final sender = chat.aliasOf(last.senderId) ?? state.users[last.senderId]?.name ?? 'New message';
      ChatNotifications.showMessage(
        chatId: chat.id,
        chatTitle: state.titleOf(chat),
        senderName: sender,
        text: last.preview,
        isGroup: chat.isGroup,
        time: last.createdAt,
      );
    }
    _primed = true;
  }
}
