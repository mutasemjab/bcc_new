import 'dart:io';

import '../../../../core/usecase/usecase.dart';
import '../entities/status_entity.dart';

abstract interface class StatusRepository {
  /// Active (non-expired) statuses posted by any of [userIds].
  Stream<List<StatusEntity>> watchStatuses(Set<String> userIds);

  ResultFuture<void> postText({required String uid, required String text, required int backgroundColor});
  ResultFuture<void> postImage({required String uid, required File image, String caption = ''});
  ResultFuture<void> markViewed(String statusId, String uid);
  ResultFuture<void> delete(StatusEntity status);
}
