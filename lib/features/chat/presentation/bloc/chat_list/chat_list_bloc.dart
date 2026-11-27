import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../users/domain/entities/user_entity.dart';
import '../../../../users/domain/usecases/user_usecases.dart';
import '../../../domain/entities/chat_entity.dart';
import '../../../domain/usecases/chat_usecases.dart';

part 'chat_list_event.dart';
part 'chat_list_state.dart';

/// Real-time inbox. Lives for the whole signed-in session so every screen
/// (new chat, new group, forwarding, stories) can reuse the contact graph.
class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  ChatListBloc({
    required WatchChats watchChats,
    required WatchUsers watchUsers,
    required TogglePinChat togglePin,
    required ToggleMuteChat toggleMute,
    required MarkMessagesDelivered markDelivered,
  }) : _watchChats = watchChats,
       _watchUsers = watchUsers,
       _togglePin = togglePin,
       _toggleMute = toggleMute,
       _markDelivered = markDelivered,
       super(const ChatListState()) {
    on<ChatListStarted>(_onStarted);
    on<ChatListStopped>(_onStopped);
    on<_ChatsUpdated>(_onChatsUpdated);
    on<_UsersUpdated>((e, emit) => emit(state.copyWith(users: e.users)));
    on<ChatListFilterChanged>((e, emit) => emit(state.copyWith(filter: e.filter)));
    on<ChatListSearchChanged>((e, emit) => emit(state.copyWith(query: e.query)));
    on<ChatPinToggled>((e, emit) => _togglePin((e.chat.id, state.uid, !e.chat.isPinnedFor(state.uid))));
    on<ChatMuteToggled>((e, emit) => _toggleMute((e.chat.id, state.uid, !e.chat.isMutedFor(state.uid))));
  }

  final WatchChats _watchChats;
  final WatchUsers _watchUsers;
  final TogglePinChat _togglePin;
  final ToggleMuteChat _toggleMute;
  final MarkMessagesDelivered _markDelivered;

  StreamSubscription<List<ChatEntity>>? _chatsSub;
  StreamSubscription<Map<String, UserEntity>>? _usersSub;
  Set<String> _watchedUserIds = {};
  final _deliveredMarks = <String>{}; // "chatId:lastMessageId" already processed

  Future<void> _onStarted(ChatListStarted e, Emitter<ChatListState> emit) async {
    if (state.uid == e.uid && _chatsSub != null) return;
    await _cancel();
    emit(ChatListState(uid: e.uid, status: ChatListStatus.loading));
    _chatsSub = _watchChats(
      e.uid,
    ).listen((chats) => add(_ChatsUpdated(chats)), onError: (Object _) => add(const _ChatsUpdated(null)));
  }

  Future<void> _onStopped(ChatListStopped e, Emitter<ChatListState> emit) async {
    await _cancel();
    emit(const ChatListState());
  }

  void _onChatsUpdated(_ChatsUpdated e, Emitter<ChatListState> emit) {
    if (e.chats == null) {
      emit(state.copyWith(status: ChatListStatus.failure));
      return;
    }
    final chats = e.chats!;
    emit(state.copyWith(chats: chats, status: ChatListStatus.ready));

    // Keep presence/profile streams for everyone we talk to.
    final ids = {for (final c in chats) ...c.participants}..remove(state.uid);
    if (!_sameSet(ids, _watchedUserIds)) {
      _watchedUserIds = ids;
      _usersSub?.cancel();
      _usersSub = _watchUsers(ids).listen((u) => add(_UsersUpdated(u)));
    }

    // Double grey tick: the message reached this device.
    for (final c in chats) {
      final last = c.lastMessage;
      final unread = c.unreadFor(state.uid);
      if (last == null || unread == 0 || last.senderId == state.uid) continue;
      final key = '${c.id}:${last.id}';
      if (_deliveredMarks.add(key)) _markDelivered((c.id, state.uid, unread));
    }
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  Future<void> _cancel() async {
    await _chatsSub?.cancel();
    await _usersSub?.cancel();
    _chatsSub = null;
    _usersSub = null;
    _watchedUserIds = {};
    _deliveredMarks.clear();
  }

  @override
  Future<void> close() async {
    await _cancel();
    return super.close();
  }
}
