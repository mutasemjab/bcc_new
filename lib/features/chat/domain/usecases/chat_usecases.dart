import '../../../../core/usecase/usecase.dart';
import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';

class WatchChats extends StreamUseCase<List<ChatEntity>, String> {
  const WatchChats(this._repo);
  final ChatRepository _repo;

  /// Sorted: pinned first, then most recent activity.
  @override
  Stream<List<ChatEntity>> call(String uid) => _repo.watchChats(uid).map((chats) {
    final sorted = [...chats]..sort((a, b) {
      final pa = a.isPinnedFor(uid), pb = b.isPinnedFor(uid);
      if (pa != pb) return pa ? -1 : 1;
      final ta = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return sorted;
  });
}

class WatchChat extends StreamUseCase<ChatEntity?, String> {
  const WatchChat(this._repo);
  final ChatRepository _repo;
  @override
  Stream<ChatEntity?> call(String chatId) => _repo.watchChat(chatId);
}

class EnsureDirectChat extends UseCase<String, (String me, String other)> {
  const EnsureDirectChat(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<String> call((String, String) p) => _repo.ensureDirectChat(p.$1, p.$2);
}

class SetTyping extends UseCase<void, (String chatId, String uid, bool typing)> {
  const SetTyping(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call((String, String, bool) p) => _repo.setTyping(p.$1, p.$2, p.$3);
}

class MarkChatRead extends UseCase<void, (String chatId, String uid)> {
  const MarkChatRead(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call((String, String) p) => _repo.markChatRead(p.$1, p.$2);
}

class TogglePinChat extends UseCase<void, (String chatId, String uid, bool pinned)> {
  const TogglePinChat(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call((String, String, bool) p) => _repo.togglePin(p.$1, p.$2, p.$3);
}

class ToggleMuteChat extends UseCase<void, (String chatId, String uid, bool muted)> {
  const ToggleMuteChat(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call((String, String, bool) p) => _repo.toggleMute(p.$1, p.$2, p.$3);
}

class MarkMessagesDelivered extends UseCase<void, (String chatId, String uid, int count)> {
  const MarkMessagesDelivered(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call((String, String, int) p) => _repo.markRecentDelivered(p.$1, p.$2, p.$3);
}
