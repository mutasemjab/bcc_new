import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/chat_entity.dart';
import '../entities/group_invite.dart';
import '../entities/message_entity.dart';
import '../entities/outgoing_message.dart';
import '../entities/scheduled_message.dart';
import '../repositories/chat_repository.dart';

/// Use cases for group invitations, anonymous membership and join links.
class GroupMembership {
  const GroupMembership(this._repo);
  final ChatRepository _repo;

  Stream<List<ChatEntity>> invitations(String uid) => _repo.watchInvitations(uid);

  /// [alias] non-null → join anonymously.
  ResultFuture<void> accept(String chatId, String uid, String name, {String? alias}) =>
      _repo.acceptInvite(chatId, uid, name, alias: alias);

  ResultFuture<void> decline(String chatId, String uid) => _repo.declineInvite(chatId, uid);
  ResultFuture<void> cancelInvite(String chatId, String uid) => _repo.cancelInvite(chatId, uid);

  ResultFuture<void> reveal(ChatEntity chat, String uid, String name) {
    final alias = chat.aliasOf(uid);
    if (alias == null) return Future.value(const Right(null));
    return _repo.revealIdentity(chat.id, uid, name, alias);
  }

  /// Fails while the 24h cooldown after revealing is still running.
  ResultFuture<void> hide(ChatEntity chat, String uid, String name, String alias) {
    final until = chat.canHideAgainAt(uid);
    if (until != null) {
      return Future.value(Left(ValidationFailure('You can hide your identity again ${formatUntil(until)}.')));
    }
    return _repo.hideIdentity(chat.id, uid, name, alias);
  }

  ResultFuture<String> createLink(String chatId) => _repo.createInviteLink(chatId);
  ResultFuture<void> revokeLink(String chatId, String code) => _repo.revokeInviteLink(chatId, code);
  ResultFuture<GroupInvitePreview?> preview(String code) => _repo.getInvite(code);
  ResultFuture<void> joinWithLink(String chatId, String code, String uid, String name, {String? alias}) =>
      _repo.joinWithLink(chatId, code, uid, name, alias: alias);

  /// "at 14:05 today" / "at 09:30 tomorrow"
  static String formatUntil(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0'), m = t.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return 'at $h:$m ${sameDay ? 'today' : 'tomorrow'}';
  }
}

/// Pinned messages, scheduled messages and chat history.
class ChatTools {
  const ChatTools(this._repo);
  final ChatRepository _repo;

  ResultFuture<void> pin(String chatId, MessageEntity m, String uid) => _repo.pinMessage(chatId, m, uid);
  ResultFuture<void> unpin(String chatId, String messageId) => _repo.unpinMessage(chatId, messageId);

  Stream<List<ScheduledMessage>> scheduled(String uid) => _repo.watchScheduled(uid);

  ResultFuture<void> schedule(ScheduledMessage m) {
    if (m.text.trim().isEmpty) return Future.value(const Left(ValidationFailure('Message is empty.')));
    if (!m.sendAt.isAfter(DateTime.now())) {
      return Future.value(const Left(ValidationFailure('Pick a time in the future.')));
    }
    return _repo.scheduleMessage(m);
  }

  ResultFuture<void> deleteScheduled(String uid, String id) => _repo.deleteScheduled(uid, id);
  ResultFuture<void> sendScheduledNow(ScheduledMessage m) => _repo.dispatchScheduled(m);
  ResultFuture<List<MessageEntity>> history(String chatId) => _repo.recentHistory(chatId);

  ResultFuture<void> clearChat(String chatId, String uid) => _repo.clearChat(chatId, uid);
  ResultFuture<void> deleteChat(String chatId, String uid) => _repo.deleteChat(chatId, uid);
  ResultFuture<void> markOpened(String chatId, String messageId, String uid) =>
      _repo.markOpened(chatId, messageId, uid);

  static const maxForwardTargets = 5;

  /// Forwards [m] to each target chat, re-using its uploaded media.
  /// [targets]: (chatId, participants, isGroup).
  ResultFuture<void> forward(
    MessageEntity m,
    String senderId,
    List<({String chatId, List<String> participants, bool isGroup})> targets,
  ) async {
    if (m.viewOnce) return const Left(ValidationFailure("View-once messages can't be forwarded."));
    if (m.type == MessageType.poll || m.type == MessageType.system) {
      return const Left(ValidationFailure("This message can't be forwarded."));
    }
    if (targets.length > maxForwardTargets) {
      return const Left(ValidationFailure('You can forward to up to 5 chats at a time.'));
    }
    for (final t in targets) {
      final r = await _repo.sendMessage(
        OutgoingMessage(
          chatId: t.chatId,
          senderId: senderId,
          participants: t.participants,
          isGroup: t.isGroup,
          type: m.type,
          text: m.text,
          fileName: m.fileName,
          fileSize: m.fileSize,
          duration: m.duration,
          waveform: m.waveform,
          latitude: m.latitude,
          longitude: m.longitude,
          stickerId: m.stickerId,
          existingMediaUrl: m.mediaUrl,
          forwardCount: m.forwardCount + 1,
        ),
      );
      if (r.isLeft()) return r;
    }
    return const Right(null);
  }
}
