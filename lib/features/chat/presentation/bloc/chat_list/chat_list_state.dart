part of 'chat_list_bloc.dart';

enum ChatListStatus { idle, loading, ready, failure }

enum ChatFilter { all, unread, groups }

class ChatListState extends Equatable {
  const ChatListState({
    this.uid = '',
    this.status = ChatListStatus.idle,
    this.chats = const [],
    this.users = const {},
    this.filter = ChatFilter.all,
    this.query = '',
  });

  final String uid;
  final ChatListStatus status;
  final List<ChatEntity> chats;
  final Map<String, UserEntity> users;
  final ChatFilter filter;
  final String query;

  /// Display title for any chat (group name or the peer's name).
  String titleOf(ChatEntity chat) {
    if (chat.isGroup) return chat.name ?? tr('Group');
    return users[chat.peerId(uid)]?.name ?? '';
  }

  String? photoOf(ChatEntity chat) => chat.isGroup ? chat.photoUrl : users[chat.peerId(uid)]?.photoUrl;

  UserEntity? peerOf(ChatEntity chat) => chat.isGroup ? null : users[chat.peerId(uid)];

  /// People I already talk to 1:1 — used as "contacts" across the app.
  List<UserEntity> get contacts {
    final list = users.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<ChatEntity> get visibleChats {
    final q = query.trim().toLowerCase();
    return chats.where((c) {
      // Hide empty 1:1 chats that were opened but never used.
      if (!c.isGroup && c.lastMessage == null) return false;
      // "Delete chat": hidden until a new message arrives.
      if (c.isDeletedFor(uid)) return false;
      switch (filter) {
        case ChatFilter.unread:
          if (c.unreadFor(uid) == 0) return false;
        case ChatFilter.groups:
          if (!c.isGroup) return false;
        case ChatFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      return titleOf(c).toLowerCase().contains(q) || (c.lastMessage?.preview.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Like WhatsApp: the number of *chats* with unread messages (muted ones excluded).
  int get totalUnread => chats.where((c) => !c.isMutedFor(uid) && !c.isDeletedFor(uid) && c.unreadFor(uid) > 0).length;

  ChatListState copyWith({
    ChatListStatus? status,
    List<ChatEntity>? chats,
    Map<String, UserEntity>? users,
    ChatFilter? filter,
    String? query,
  }) => ChatListState(
    uid: uid,
    status: status ?? this.status,
    chats: chats ?? this.chats,
    users: users ?? this.users,
    filter: filter ?? this.filter,
    query: query ?? this.query,
  );

  @override
  List<Object?> get props => [uid, status, chats, users, filter, query];
}
