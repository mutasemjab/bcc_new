import 'dart:io';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._remote);
  final UserRemoteDataSource _remote;

  @override
  Stream<UserEntity?> watchUser(String uid) => _remote.watchUser(uid);

  @override
  Stream<Map<String, UserEntity>> watchUsers(Set<String> uids) => _remote.watchUsers(uids);

  @override
  ResultFuture<UserEntity?> getUser(String uid) => guard(() => _remote.getUser(uid));

  @override
  ResultFuture<UserEntity> saveProfile({
    required String uid,
    required String name,
    required String about,
    File? avatar,
    String? email,
    String? phone,
  }) =>
      guard(() => _remote.saveProfile(uid: uid, name: name, about: about, avatar: avatar, email: email, phone: phone));

  @override
  ResultFuture<List<UserEntity>> search(String query, {required String excludeUid}) =>
      guard(() => _remote.search(query, excludeUid));

  @override
  ResultFuture<List<UserEntity>> findByPhones(List<String> phones, {required String excludeUid}) =>
      guard(() => _remote.findByPhones(phones, excludeUid));

  @override
  ResultFuture<void> setPresence(String uid, {required bool online}) => guard(() => _remote.setPresence(uid, online));

  @override
  ResultFuture<void> registerPushToken(String uid, String token) =>
      guard(() => _remote.updateTokens(uid, token, add: true));

  @override
  ResultFuture<void> removePushToken(String uid, String token) =>
      guard(() => _remote.updateTokens(uid, token, add: false));

  @override
  ResultFuture<void> updatePrivacy(String uid, {bool? hideLastSeen, bool? hideOnline, bool? readReceipts}) => guard(
    () => _remote.updatePrivacy(uid, hideLastSeen: hideLastSeen, hideOnline: hideOnline, readReceipts: readReceipts),
  );

  @override
  Stream<Set<String>> watchBlocked(String uid) => _remote.watchBlocked(uid);

  @override
  ResultFuture<void> setBlocked(String uid, String other, {required bool blocked}) =>
      guard(() => _remote.setBlocked(uid, other, blocked: blocked));
}
