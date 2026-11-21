import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/message_entity.dart';
import '../entities/outgoing_message.dart';
import '../repositories/chat_repository.dart';

class WatchMessages extends StreamUseCase<List<MessageEntity>, (String chatId, int limit, DateTime? after)> {
  const WatchMessages(this._repo);
  final ChatRepository _repo;
  @override
  Stream<List<MessageEntity>> call((String, int, DateTime?) p) => _repo.watchMessages(p.$1, limit: p.$2, after: p.$3);
}

class SendMessageParams {
  const SendMessageParams(this.message, {this.onProgress});
  final OutgoingMessage message;
  final void Function(double progress)? onProgress;
}

class SendMessage extends UseCase<void, SendMessageParams> {
  const SendMessage(this._repo);
  final ChatRepository _repo;

  static const maxFileBytes = 100 * 1024 * 1024; // 100 MB

  @override
  ResultFuture<void> call(SendMessageParams p) async {
    final m = p.message;
    if (m.type == MessageType.text && m.text.trim().isEmpty) {
      return const Left(ValidationFailure('Message is empty.'));
    }
    if (m.type == MessageType.text && m.text.length > 4096) {
      return const Left(ValidationFailure('Message is too long.'));
    }
    if (m.type == MessageType.poll) {
      final poll = m.poll;
      if (poll == null || poll.question.trim().isEmpty) return const Left(ValidationFailure('Write a question.'));
      if (poll.options.where((o) => o.text.trim().isNotEmpty).length < 2) {
        return const Left(ValidationFailure('Add at least two options.'));
      }
    }
    if ((m.fileSize ?? 0) > maxFileBytes) {
      return const Left(ValidationFailure('Files must be smaller than 100 MB.'));
    }
    return _repo.sendMessage(m, onProgress: p.onProgress);
  }
}

/// `read` false → only "delivered" (the user turned read receipts off).
class MarkMessagesRead extends UseCase<void, (String chatId, String uid, List<String> ids, bool read)> {
  const MarkMessagesRead(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call((String, String, List<String>, bool) p) async {
    if (p.$3.isEmpty) return const Right(null);
    return _repo.markMessagesRead(p.$1, p.$2, p.$3, read: p.$4);
  }
}

class DeleteMessage extends UseCase<void, ({String chatId, String messageId, String uid, bool forEveryone})> {
  const DeleteMessage(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(({String chatId, String messageId, String uid, bool forEveryone}) p) =>
      p.forEveryone ? _repo.deleteForEveryone(p.chatId, p.messageId) : _repo.deleteForMe(p.chatId, p.messageId, p.uid);
}

class EditMessage extends UseCase<void, (String chatId, String messageId, String text)> {
  const EditMessage(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call((String, String, String) p) async {
    if (p.$3.trim().isEmpty) return const Left(ValidationFailure('Message is empty.'));
    return _repo.editMessage(p.$1, p.$2, p.$3.trim());
  }
}

class ReactToMessage extends UseCase<void, ({String chatId, String messageId, String uid, String? emoji})> {
  const ReactToMessage(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(({String chatId, String messageId, String uid, String? emoji}) p) =>
      _repo.react(p.chatId, p.messageId, p.uid, p.emoji);
}

class VotePoll extends UseCase<void, ({String chatId, String messageId, String uid, List<String> optionIds})> {
  const VotePoll(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(({String chatId, String messageId, String uid, List<String> optionIds}) p) =>
      _repo.votePoll(p.chatId, p.messageId, p.uid, p.optionIds);
}
