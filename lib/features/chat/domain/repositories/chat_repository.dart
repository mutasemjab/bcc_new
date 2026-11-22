import 'dart:io';

import '../../../../core/usecase/usecase.dart';
import '../entities/chat_entity.dart';
import '../entities/group_invite.dart';
import '../entities/message_entity.dart';
import '../entities/outgoing_message.dart';
import '../entities/scheduled_message.dart';

abstract interface class ChatRepository {
  // ── Chats ──────────────────────────────────────────────────────────────
  Stream<List<ChatEntity>> watchChats(String uid);
  Stream<ChatEntity?> watchChat(String chatId);

  /// Returns the chat id (deterministic for 1:1).
  ResultFuture<String> ensureDirectChat(String me, String other);

  ResultFuture<void> setTyping(String chatId, String uid, bool typing);
  ResultFuture<void> markChatRead(String chatId, String uid);
  ResultFuture<void> togglePin(String chatId, String uid, bool pinned);
  ResultFuture<void> toggleMute(String chatId, String uid, bool muted);

  // ── Messages ───────────────────────────────────────────────────────────
  Stream<List<MessageEntity>> watchMessages(String chatId, {required int limit, DateTime? after});

  ResultFuture<void> sendMessage(OutgoingMessage message, {void Function(double)? onProgress});

  ResultFuture<void> markMessagesRead(String chatId, String uid, List<String> messageIds, {bool read = true});
  ResultFuture<void> clearChat(String chatId, String uid);
  ResultFuture<void> deleteChat(String chatId, String uid);
  ResultFuture<void> markOpened(String chatId, String messageId, String uid);

  /// Marks the latest [count] incoming messages as delivered to [uid].
  ResultFuture<void> markRecentDelivered(String chatId, String uid, int count);
  ResultFuture<void> deleteForMe(String chatId, String messageId, String uid);
  ResultFuture<void> deleteForEveryone(String chatId, String messageId);
  ResultFuture<void> editMessage(String chatId, String messageId, String newText);
  ResultFuture<void> react(String chatId, String messageId, String uid, String? emoji);
  ResultFuture<void> votePoll(String chatId, String messageId, String uid, List<String> optionIds);

  // ── Groups ─────────────────────────────────────────────────────────────
  ResultFuture<String> createGroup({
    required String creatorId,
    required String creatorName,
    required String name,
    required List<String> memberIds,
    String? description,
    File? photo,
  });

  ResultFuture<void> updateGroup(String chatId, {String? name, String? description, File? photo});
  ResultFuture<void> addMembers(
    String chatId,
    List<String> uids, {
    required String actorId,
    required String actorName,
    required List<String> names,
  });
  ResultFuture<void> removeMember(
    String chatId,
    String uid, {
    required String actorId,
    required String actorName,
    required String memberName,
  });
  ResultFuture<void> leaveGroup(String chatId, String uid, {required String name});
  ResultFuture<void> setAdmin(String chatId, String uid, bool isAdmin);

  // ── Invitations, anonymity, join links ─────────────────────────────────
  Stream<List<ChatEntity>> watchInvitations(String uid);
  ResultFuture<void> acceptInvite(String chatId, String uid, String name, {String? alias});
  ResultFuture<void> declineInvite(String chatId, String uid);
  ResultFuture<void> cancelInvite(String chatId, String uid);
  ResultFuture<({int existing, int pending})> inviteByEmail(
    String chatId,
    List<String> emails,
    String actorId,
    String actorName,
  );
  ResultFuture<void> cancelEmailInvite(String chatId, String email);
  ResultFuture<int> claimEmailInvites(String uid, String email);
  ResultFuture<void> revealIdentity(String chatId, String uid, String name, String alias);
  ResultFuture<void> hideIdentity(String chatId, String uid, String name, String alias);
  ResultFuture<String> createInviteLink(String chatId);
  ResultFuture<void> revokeInviteLink(String chatId, String code);
  ResultFuture<GroupInvitePreview?> getInvite(String code);
  ResultFuture<void> joinWithLink(String chatId, String code, String uid, String name, {String? alias});

  // ── Pins, scheduling, history ──────────────────────────────────────────
  ResultFuture<void> pinMessage(String chatId, MessageEntity message, String uid);
  ResultFuture<void> unpinMessage(String chatId, String messageId);
  Stream<List<ScheduledMessage>> watchScheduled(String uid);
  ResultFuture<void> scheduleMessage(ScheduledMessage message);
  ResultFuture<void> deleteScheduled(String uid, String id);
  ResultFuture<void> dispatchScheduled(ScheduledMessage message);
  ResultFuture<List<MessageEntity>> recentHistory(String chatId);
  ResultFuture<List<MessageEntity>> fullHistory(String chatId);

  // ── Group lifecycle & moderation ───────────────────────────────────────
  ResultFuture<void> endGroup(String chatId, String uid, String name);
  ResultFuture<void> rejoinGroup(String chatId, String uid, String name, {String? alias});
  ResultFuture<void> setSecret(String chatId, bool secret);
  ResultFuture<void> setAutoClear(String chatId, String uid, bool on);
  ResultFuture<void> reviewMedia(String chatId, String messageId, String adminId, {required bool approve});
}
