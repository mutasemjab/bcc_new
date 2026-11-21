part of 'conversation_bloc.dart';

enum ConversationStatus { loading, ready }

/// A media message that is still uploading (rendered as a bubble with progress).
class PendingUpload extends Equatable {
  const PendingUpload({
    required this.id,
    required this.type,
    required this.localPath,
    this.fileName,
    this.progress = 0,
  });
  final String id;
  final MessageType type;
  final String localPath;
  final String? fileName;
  final double progress;

  PendingUpload withProgress(double p) =>
      PendingUpload(id: id, type: type, localPath: localPath, fileName: fileName, progress: p);

  @override
  List<Object?> get props => [id, progress];
}

class ConversationState extends Equatable {
  const ConversationState({
    this.chatId = '',
    this.me,
    this.chat,
    this.status = ConversationStatus.loading,
    this.messages = const [],
    this.users = const {},
    this.limit = 40,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.replyingTo,
    this.editing,
    this.uploads = const [],
    this.isMember = true,
    this.error,
  });

  final String chatId;
  final UserEntity? me;
  final ChatEntity? chat;
  final ConversationStatus status;

  /// Newest first (the list view is reversed).
  final List<MessageEntity> messages;
  final Map<String, UserEntity> users;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;
  final MessageEntity? replyingTo;
  final MessageEntity? editing;
  final List<PendingUpload> uploads;
  final bool isMember;

  /// One-shot error; the UI shows it and it is cleared by the next emit.
  final String? error;

  bool get isGroup => chat?.isGroup ?? false;

  UserEntity? get peer {
    final me = this.me;
    if (me == null) return null;
    final id = IdUtils.peerFromChatId(chatId, me.id);
    return id == null ? null : users[id];
  }

  String get title => isGroup ? (chat?.name ?? 'Group') : (peer?.name ?? '');
  String? get photoUrl => isGroup ? chat?.photoUrl : peer?.photoUrl;

  /// Display name, respecting anonymous group members.
  String nameOf(String uid) {
    if (uid == me?.id) return 'You';
    return chat?.aliasOf(uid) ?? users[uid]?.name ?? 'Unknown';
  }

  /// Profile photo, hidden for anonymous group members.
  String? photoOf(String uid) => (chat?.isAnonymous(uid) ?? false) ? null : users[uid]?.photoUrl;

  /// Users with anonymous members masked (alias, no photo) — for calls etc.
  Map<String, UserEntity> get displayUsers => {
    for (final e in users.entries)
      e.key: chat?.aliasOf(e.key) == null ? e.value : UserEntity(id: e.key, name: chat!.aliasOf(e.key)!),
  };

  /// Whether I am anonymous in this group.
  bool get amAnonymous => me != null && (chat?.isAnonymous(me!.id) ?? false);

  List<String> get typingNames {
    final me = this.me;
    if (me == null || chat == null) return const [];
    return chat!.typingUsers(me.id).map((id) => chat!.aliasOf(id) ?? users[id]?.name.split(' ').first ?? '').toList();
  }

  List<String> get participants => chat?.participants ?? const [];

  ConversationState copyWith({
    String? chatId,
    UserEntity? me,
    ChatEntity? chat,
    ConversationStatus? status,
    List<MessageEntity>? messages,
    Map<String, UserEntity>? users,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
    MessageEntity? Function()? replyingTo,
    MessageEntity? Function()? editing,
    List<PendingUpload>? uploads,
    bool? isMember,
    String? error,
  }) => ConversationState(
    chatId: chatId ?? this.chatId,
    me: me ?? this.me,
    chat: chat ?? this.chat,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    users: users ?? this.users,
    limit: limit ?? this.limit,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    replyingTo: replyingTo != null ? replyingTo() : this.replyingTo,
    editing: editing != null ? editing() : this.editing,
    uploads: uploads ?? this.uploads,
    isMember: isMember ?? this.isMember,
    error: error,
  );

  @override
  List<Object?> get props => [
    chatId,
    me,
    chat,
    status,
    messages,
    users,
    limit,
    hasMore,
    isLoadingMore,
    replyingTo,
    editing,
    uploads,
    isMember,
    error,
  ];
}
