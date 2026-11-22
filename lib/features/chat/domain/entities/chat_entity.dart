import 'package:equatable/equatable.dart';

import 'message_entity.dart';

class LastMessage extends Equatable {
  const LastMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.preview,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String preview;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, senderId, type, preview, createdAt];
}

/// A conversation: either a 1:1 direct chat or a group.
class ChatEntity extends Equatable {
  const ChatEntity({
    required this.id,
    required this.isGroup,
    required this.participants,
    this.name,
    this.photoUrl,
    this.description,
    this.admins = const [],
    this.createdBy,
    this.lastMessage,
    this.updatedAt,
    this.unread = const {},
    this.typing = const {},
    this.pinnedBy = const [],
    this.mutedBy = const [],
    this.invited = const [],
    this.invitedBy = const {},
    this.anonymous = const {},
    this.revealedAt = const {},
    this.pinnedMessages = const [],
    this.inviteCode,
    this.clearedAt = const {},
    this.deletedAt = const {},
    this.secret = false,
    this.closed = false,
    this.formerMembers = const [],
    this.autoClear = const {},
    this.invitedEmails = const [],
  });

  final String id;
  final bool isGroup;
  final List<String> participants;

  // Group-only metadata
  final String? name;
  final String? photoUrl;
  final String? description;
  final List<String> admins;
  final String? createdBy;

  final LastMessage? lastMessage;
  final DateTime? updatedAt;

  /// uid → unread count
  final Map<String, int> unread;

  /// uid → currently typing
  final Map<String, bool> typing;

  final List<String> pinnedBy;
  final List<String> mutedBy;

  /// Groups: people who were added but have not accepted yet.
  final List<String> invited;

  /// invitee uid → uid of who invited them.
  final Map<String, String> invitedBy;

  /// Groups: members who joined anonymously, uid → alias ("Member #4821").
  final Map<String, String> anonymous;

  /// When each member last revealed their identity (24h cooldown to hide again).
  final Map<String, DateTime> revealedAt;

  /// Newest first, max 3.
  final List<PinnedMessage> pinnedMessages;

  /// Current join-link code (groups).
  final String? inviteCode;

  /// uid → when they cleared the chat (older messages are hidden for them).
  final Map<String, DateTime> clearedAt;

  /// uid → when they deleted the chat (hidden from their list until a newer message).
  final Map<String, DateTime> deletedAt;

  /// Groups: "secret" (admin setting) — members can't share join links and
  /// can't rejoin by themselves after leaving.
  final bool secret;

  /// Groups: ended by the owner (owner left). Read-only for everyone.
  final bool closed;

  /// Groups: people who left on their own (they may rejoin if not secret).
  final List<String> formerMembers;

  /// Groups: emails of people invited before they had an account. They get
  /// the invitation once they sign up (and verify) with that email.
  final List<String> invitedEmails;

  /// Everyone still waiting to join (accounts + email-only).
  int get pendingInviteCount => invited.length + invitedEmails.length;

  /// uid → clear this chat automatically every day.
  final Map<String, bool> autoClear;

  bool get isOwnerLess => createdBy == null;
  bool isOwner(String uid) => createdBy == uid;
  bool isFormerMember(String uid) => formerMembers.contains(uid) && !participants.contains(uid);
  bool canRejoin(String uid) => isGroup && !secret && !closed && isFormerMember(uid);
  bool autoClearsFor(String uid) => autoClear[uid] == true;

  /// Non-admin members may share the join link only in non-secret groups.
  bool canShareLink(String uid) => isGroup && !closed && (isAdmin(uid) || (!secret && participants.contains(uid)));

  /// Whether [uid] deleted this chat and nothing new arrived since.
  bool isDeletedFor(String uid) {
    final at = deletedAt[uid];
    if (at == null) return false;
    final last = lastMessage?.createdAt;
    return last == null || !last.isAfter(at);
  }

  /// Whether the last message predates [uid]'s "clear chat".
  bool isClearedFor(String uid) {
    final at = clearedAt[uid];
    final last = lastMessage?.createdAt;
    return at != null && (last == null || !last.isAfter(at));
  }

  static const anonymousCooldown = Duration(hours: 24);

  bool isInvited(String uid) => invited.contains(uid);
  bool isAnonymous(String uid) => anonymous.containsKey(uid);
  String? aliasOf(String uid) => anonymous[uid];

  /// When [uid] may hide their identity again (null = allowed now).
  DateTime? canHideAgainAt(String uid, {DateTime? now}) {
    final at = revealedAt[uid];
    if (at == null) return null;
    final until = at.add(anonymousCooldown);
    return until.isAfter(now ?? DateTime.now()) ? until : null;
  }

  /// Groups I left can't be marked read anymore → never count them as unread.
  int unreadFor(String uid) => isGroup && !participants.contains(uid) ? 0 : (unread[uid] ?? 0);
  bool isAdmin(String uid) => admins.contains(uid);
  bool isPinnedFor(String uid) => pinnedBy.contains(uid);
  bool isMutedFor(String uid) => mutedBy.contains(uid);

  /// For direct chats: the other participant.
  String? peerId(String me) => isGroup ? null : participants.firstWhere((p) => p != me, orElse: () => me);

  List<String> typingUsers(String me) => typing.entries.where((e) => e.value && e.key != me).map((e) => e.key).toList();

  @override
  List<Object?> get props => [
    id,
    isGroup,
    participants,
    name,
    photoUrl,
    description,
    admins,
    createdBy,
    lastMessage,
    updatedAt,
    unread,
    typing,
    pinnedBy,
    mutedBy,
    invited,
    invitedBy,
    anonymous,
    revealedAt,
    pinnedMessages,
    inviteCode,
    clearedAt,
    deletedAt,
    secret,
    closed,
    formerMembers,
    autoClear,
    invitedEmails,
  ];
}

/// A message pinned to the top of a chat.
class PinnedMessage extends Equatable {
  const PinnedMessage({
    required this.messageId,
    required this.senderId,
    required this.type,
    required this.preview,
    required this.pinnedBy,
    this.pinnedAt,
  });

  final String messageId;
  final String senderId;
  final MessageType type;
  final String preview;
  final String pinnedBy;
  final DateTime? pinnedAt;

  @override
  List<Object?> get props => [messageId, senderId, type, preview, pinnedBy, pinnedAt];
}
