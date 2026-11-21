part of 'chat_list_bloc.dart';

sealed class ChatListEvent extends Equatable {
  const ChatListEvent();
  @override
  List<Object?> get props => [];
}

class ChatListStarted extends ChatListEvent {
  const ChatListStarted(this.uid);
  final String uid;
  @override
  List<Object?> get props => [uid];
}

class ChatListStopped extends ChatListEvent {
  const ChatListStopped();
}

class ChatListFilterChanged extends ChatListEvent {
  const ChatListFilterChanged(this.filter);
  final ChatFilter filter;
  @override
  List<Object?> get props => [filter];
}

class ChatListSearchChanged extends ChatListEvent {
  const ChatListSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class ChatPinToggled extends ChatListEvent {
  const ChatPinToggled(this.chat);
  final ChatEntity chat;
  @override
  List<Object?> get props => [chat.id];
}

class ChatMuteToggled extends ChatListEvent {
  const ChatMuteToggled(this.chat);
  final ChatEntity chat;
  @override
  List<Object?> get props => [chat.id];
}

class _ChatsUpdated extends ChatListEvent {
  const _ChatsUpdated(this.chats);
  final List<ChatEntity>? chats;
  @override
  List<Object?> get props => [chats];
}

class _UsersUpdated extends ChatListEvent {
  const _UsersUpdated(this.users);
  final Map<String, UserEntity> users;
  @override
  List<Object?> get props => [users];
}
