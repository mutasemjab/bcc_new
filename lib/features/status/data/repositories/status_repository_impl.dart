import 'dart:io';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/status_entity.dart';
import '../../domain/repositories/status_repository.dart';
import '../datasources/status_remote_data_source.dart';

class StatusRepositoryImpl implements StatusRepository {
  StatusRepositoryImpl(this._remote);
  final StatusRemoteDataSource _remote;

  @override
  Stream<List<StatusEntity>> watchStatuses(Set<String> userIds) => _remote.watch(userIds);

  @override
  ResultFuture<void> postText({required String uid, required String text, required int backgroundColor}) =>
      guard(() => _remote.postText(uid, text, backgroundColor));

  @override
  ResultFuture<void> postImage({required String uid, required File image, String caption = ''}) =>
      guard(() => _remote.postImage(uid, image, caption));

  @override
  ResultFuture<void> markViewed(String statusId, String uid) => guard(() => _remote.markViewed(statusId, uid));

  @override
  ResultFuture<void> delete(StatusEntity status) => guard(() => _remote.delete(status));
}
