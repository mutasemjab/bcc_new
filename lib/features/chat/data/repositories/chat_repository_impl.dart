import 'dart:io';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/outgoing_message.dart';
import '../../domain/entities/scheduled_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote);
  final ChatRemoteDataSource _remote;

  @override
  Stream<List<ChatEntity>> watchChats(String uid) => _remote.watchChats(uid);

  @override
  Stream<ChatEntity?> watchChat(String chatId) => _remote.watchChat(chatId);

  @override
  ResultFuture<String> ensureDirectChat(String me, String other) => guard(() => _remote.ensureDirectChat(me, other));

  @override
  ResultFuture<void> setTyping(String chatId, String uid, bool typing) =>
      guard(() => _remote.setTyping(chatId, uid, typing));

  @override
  ResultFuture<void> markChatRead(String chatId, String uid) => guard(() => _remote.markChatRead(chatId, uid));

  @override
  ResultFuture<void> togglePin(String chatId, String uid, bool pinned) =>
      guard(() => _remote.togglePin(chatId, uid, pinned));

  @override
  ResultFuture<void> toggleMute(String chatId, String uid, bool muted) =>
      guard(() => _remote.toggleMute(chatId, uid, muted));

  @override
  Stream<List<MessageEntity>> watchMessages(String chatId, {required int limit, DateTime? after}) =>
      _remote.watchMessages(chatId, limit, after: after);

  @override
  ResultFuture<void> sendMessage(OutgoingMessage message, {void Function(double)? onProgress}) =>
      guard(() => _remote.sendMessage(message, onProgress: onProgress));

  @override
  ResultFuture<void> markMessagesRead(String chatId, String uid, List<String> messageIds, {bool read = true}) =>
      guard(() => _remote.markMessagesRead(chatId, uid, messageIds, read: read));

  @override
  ResultFuture<void> clearChat(String chatId, String uid) => guard(() => _remote.clearChat(chatId, uid));

  @override
  ResultFuture<void> deleteChat(String chatId, String uid) => guard(() => _remote.deleteChat(chatId, uid));

  @override
  ResultFuture<void> markOpened(String chatId, String messageId, String uid) =>
      guard(() => _remote.markOpened(chatId, messageId, uid));

  @override
  ResultFuture<void> markRecentDelivered(String chatId, String uid, int count) =>
      guard(() => _remote.markRecentDelivered(chatId, uid, count));

  @override
  ResultFuture<void> deleteForMe(String chatId, String messageId, String uid) =>
      guard(() => _remote.deleteForMe(chatId, messageId, uid));

  @override
  ResultFuture<void> deleteForEveryone(String chatId, String messageId) =>
      guard(() => _remote.deleteForEveryone(chatId, messageId));

  @override
  ResultFuture<void> editMessage(String chatId, String messageId, String newText) =>
      guard(() => _remote.editMessage(chatId, messageId, newText));

  @override
  ResultFuture<void> react(String chatId, String messageId, String uid, String? emoji) =>
      guard(() => _remote.react(chatId, messageId, uid, emoji));

  @override
  ResultFuture<void> votePoll(String chatId, String messageId, String uid, List<String> optionIds) =>
      guard(() => _remote.votePoll(chatId, messageId, uid, optionIds));

  @override
  ResultFuture<String> createGroup({
    required String creatorId,
    required String creatorName,
    required String name,
    required List<String> memberIds,
    String? description,
    File? photo,
  }) => guard(
    () => _remote.createGroup(
      creatorId: creatorId,
      creatorName: creatorName,
      name: name,
      memberIds: memberIds,
      description: description,
      photo: photo,
    ),
  );

  @override
  ResultFuture<void> updateGroup(String chatId, {String? name, String? description, File? photo}) =>
      guard(() => _remote.updateGroup(chatId, name: name, description: description, photo: photo));

  @override
  ResultFuture<void> addMembers(
    String chatId,
    List<String> uids, {
    required String actorId,
    required String actorName,
    required List<String> names,
  }) => guard(() => _remote.addMembers(chatId, uids, actorId, actorName, names));

  @override
  ResultFuture<void> removeMember(
    String chatId,
    String uid, {
    required String actorId,
    required String actorName,
    required String memberName,
  }) => guard(() => _remote.removeMember(chatId, uid, actorId, actorName, memberName));

  @override
  ResultFuture<void> leaveGroup(String chatId, String uid, {required String name}) =>
      guard(() => _remote.leaveGroup(chatId, uid, name));

  @override
  ResultFuture<void> setAdmin(String chatId, String uid, bool isAdmin) =>
      guard(() => _remote.setAdmin(chatId, uid, isAdmin));

  @override
  Stream<List<ChatEntity>> watchInvitations(String uid) => _remote.watchInvitations(uid);

  @override
  ResultFuture<void> acceptInvite(String chatId, String uid, String name, {String? alias}) =>
      guard(() => _remote.acceptInvite(chatId, uid, name, alias: alias));

  @override
  ResultFuture<void> declineInvite(String chatId, String uid) => guard(() => _remote.declineInvite(chatId, uid));

  @override
  ResultFuture<void> cancelInvite(String chatId, String uid) => guard(() => _remote.cancelInvite(chatId, uid));

  @override
  ResultFuture<void> revealIdentity(String chatId, String uid, String name, String alias) =>
      guard(() => _remote.revealIdentity(chatId, uid, name, alias));

  @override
  ResultFuture<void> hideIdentity(String chatId, String uid, String name, String alias) =>
      guard(() => _remote.hideIdentity(chatId, uid, name, alias));

  @override
  ResultFuture<String> createInviteLink(String chatId) => guard(() => _remote.createInviteLink(chatId));

  @override
  ResultFuture<void> revokeInviteLink(String chatId, String code) =>
      guard(() => _remote.revokeInviteLink(chatId, code));

  @override
  ResultFuture<GroupInvitePreview?> getInvite(String code) => guard(() => _remote.getInvite(code));

  @override
  ResultFuture<void> joinWithLink(String chatId, String code, String uid, String name, {String? alias}) =>
      guard(() => _remote.joinWithLink(chatId, code, uid, name, alias: alias));

  @override
  ResultFuture<void> pinMessage(String chatId, MessageEntity message, String uid) =>
      guard(() => _remote.pinMessage(chatId, message, uid));

  @override
  ResultFuture<void> unpinMessage(String chatId, String messageId) =>
      guard(() => _remote.unpinMessage(chatId, messageId));

  @override
  Stream<List<ScheduledMessage>> watchScheduled(String uid) => _remote.watchScheduled(uid);

  @override
  ResultFuture<void> scheduleMessage(ScheduledMessage message) => guard(() => _remote.scheduleMessage(message));

  @override
  ResultFuture<void> deleteScheduled(String uid, String id) => guard(() => _remote.deleteScheduled(uid, id));

  @override
  ResultFuture<void> dispatchScheduled(ScheduledMessage message) => guard(() => _remote.dispatchScheduled(message));

  @override
  ResultFuture<List<MessageEntity>> recentHistory(String chatId) => guard(() => _remote.recentHistory(chatId));
}
