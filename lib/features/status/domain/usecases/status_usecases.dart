import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/status_entity.dart';
import '../repositories/status_repository.dart';

/// Groups active statuses per user: me first, then unseen (newest first),
/// then fully-seen (newest first).
class WatchStatusFeed extends StreamUseCase<List<UserStatuses>, ({String me, Set<String> contacts})> {
  const WatchStatusFeed(this._repo);
  final StatusRepository _repo;

  @override
  Stream<List<UserStatuses>> call(({String me, Set<String> contacts}) p) {
    return _repo.watchStatuses({p.me, ...p.contacts}).map((all) {
      final now = DateTime.now();
      final byUser = <String, List<StatusEntity>>{};
      for (final s in all.where((s) => s.expiresAt.isAfter(now))) {
        byUser.putIfAbsent(s.userId, () => []).add(s);
      }
      final groups =
          byUser.entries.map((e) {
            final list = [...e.value]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return UserStatuses(userId: e.key, statuses: list);
          }).toList();
      groups.sort((a, b) {
        if (a.userId == p.me) return -1;
        if (b.userId == p.me) return 1;
        final sa = a.allSeenBy(p.me), sb = b.allSeenBy(p.me);
        if (sa != sb) return sa ? 1 : -1;
        return b.latest.compareTo(a.latest);
      });
      return groups;
    });
  }
}

class PostTextStatus extends UseCase<void, ({String uid, String text, int color})> {
  const PostTextStatus(this._repo);
  final StatusRepository _repo;
  @override
  ResultFuture<void> call(({String uid, String text, int color}) p) async {
    final text = p.text.trim();
    if (text.isEmpty) return Left(ValidationFailure(tr('Write something first.')));
    if (text.length > 700) return Left(ValidationFailure(tr('Status is too long.')));
    return _repo.postText(uid: p.uid, text: text, backgroundColor: p.color);
  }
}

class PostImageStatus extends UseCase<void, ({String uid, File image, String caption})> {
  const PostImageStatus(this._repo);
  final StatusRepository _repo;
  @override
  ResultFuture<void> call(({String uid, File image, String caption}) p) =>
      _repo.postImage(uid: p.uid, image: p.image, caption: p.caption.trim());
}

class MarkStatusViewed extends UseCase<void, (String statusId, String uid)> {
  const MarkStatusViewed(this._repo);
  final StatusRepository _repo;
  @override
  ResultFuture<void> call((String, String) p) => _repo.markViewed(p.$1, p.$2);
}

class DeleteStatus extends UseCase<void, StatusEntity> {
  const DeleteStatus(this._repo);
  final StatusRepository _repo;
  @override
  ResultFuture<void> call(StatusEntity s) => _repo.delete(s);
}
