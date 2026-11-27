import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/user_repository.dart';

class WatchUser extends StreamUseCase<UserEntity?, String> {
  const WatchUser(this._repo);
  final UserRepository _repo;
  @override
  Stream<UserEntity?> call(String uid) => _repo.watchUser(uid);
}

class WatchUsers extends StreamUseCase<Map<String, UserEntity>, Set<String>> {
  const WatchUsers(this._repo);
  final UserRepository _repo;
  @override
  Stream<Map<String, UserEntity>> call(Set<String> uids) => _repo.watchUsers(uids);
}

class GetUser extends UseCase<UserEntity?, String> {
  const GetUser(this._repo);
  final UserRepository _repo;
  @override
  ResultFuture<UserEntity?> call(String uid) => _repo.getUser(uid);
}

class SaveProfileParams extends Equatable {
  const SaveProfileParams({
    required this.uid,
    required this.name,
    required this.about,
    this.avatar,
    this.email,
    this.phone,
  });
  final String uid;
  final String name;
  final String about;
  final File? avatar;
  final String? email;
  final String? phone;
  @override
  List<Object?> get props => [uid, name, about, avatar?.path, email, phone];
}

class SaveProfile extends UseCase<UserEntity, SaveProfileParams> {
  const SaveProfile(this._repo);
  final UserRepository _repo;

  @override
  ResultFuture<UserEntity> call(SaveProfileParams p) async {
    final name = p.name.trim();
    if (name.length < 2) return Left(ValidationFailure(tr('Please enter your name (2+ characters).')));
    if (name.length > 40) return Left(ValidationFailure(tr('Name is too long.')));
    return _repo.saveProfile(
      uid: p.uid,
      name: name,
      about: p.about.trim().isEmpty ? tr('Hey there! I am using BCC Chat.') : p.about.trim(),
      avatar: p.avatar,
      email: p.email,
      phone: p.phone,
    );
  }
}

class SearchUsersParams extends Equatable {
  const SearchUsersParams(this.query, this.currentUid);
  final String query;
  final String currentUid;
  @override
  List<Object?> get props => [query, currentUid];
}

class SearchUsers extends UseCase<List<UserEntity>, SearchUsersParams> {
  const SearchUsers(this._repo);
  final UserRepository _repo;
  @override
  ResultFuture<List<UserEntity>> call(SearchUsersParams p) {
    final q = p.query.trim();
    if (q.length < 2) return Future.value(const Right([]));
    return _repo.search(q, excludeUid: p.currentUid);
  }
}

class SetPresenceParams {
  const SetPresenceParams(this.uid, this.online);
  final String uid;
  final bool online;
}

class SetPresence extends UseCase<void, SetPresenceParams> {
  const SetPresence(this._repo);
  final UserRepository _repo;
  @override
  ResultFuture<void> call(SetPresenceParams p) => _repo.setPresence(p.uid, online: p.online);
}

class RegisterPushToken extends UseCase<void, (String uid, String token)> {
  const RegisterPushToken(this._repo);
  final UserRepository _repo;
  @override
  ResultFuture<void> call((String, String) p) => _repo.registerPushToken(p.$1, p.$2);
}

class FindUsersByPhones extends UseCase<List<UserEntity>, ({List<String> phones, String currentUid})> {
  const FindUsersByPhones(this._repo);
  final UserRepository _repo;
  @override
  ResultFuture<List<UserEntity>> call(({List<String> phones, String currentUid}) p) {
    if (p.phones.isEmpty) return Future.value(const Right([]));
    return _repo.findByPhones(p.phones, excludeUid: p.currentUid);
  }
}

/// Privacy settings + block list.
class PrivacySettings {
  const PrivacySettings(this._repo);
  final UserRepository _repo;

  ResultFuture<void> update(String uid, {bool? hideLastSeen, bool? hideOnline, bool? readReceipts}) =>
      _repo.updatePrivacy(uid, hideLastSeen: hideLastSeen, hideOnline: hideOnline, readReceipts: readReceipts);

  Stream<Set<String>> blocked(String uid) => _repo.watchBlocked(uid);
  ResultFuture<void> block(String uid, String other) => _repo.setBlocked(uid, other, blocked: true);
  ResultFuture<void> unblock(String uid, String other) => _repo.setBlocked(uid, other, blocked: false);
}
