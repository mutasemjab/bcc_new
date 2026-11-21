import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/chat_repository.dart';

class CreateGroupParams {
  const CreateGroupParams({
    required this.creatorId,
    required this.creatorName,
    required this.name,
    required this.memberIds,
    this.description,
    this.photo,
  });
  final String creatorId;
  final String creatorName;
  final String name;
  final List<String> memberIds;
  final String? description;
  final File? photo;
}

class CreateGroup extends UseCase<String, CreateGroupParams> {
  const CreateGroup(this._repo);
  final ChatRepository _repo;

  static const maxMembers = 256;

  @override
  ResultFuture<String> call(CreateGroupParams p) async {
    final name = p.name.trim();
    if (name.isEmpty) return const Left(ValidationFailure('Give your group a name.'));
    if (p.memberIds.isEmpty) return const Left(ValidationFailure('Add at least one member.'));
    if (p.memberIds.length + 1 > maxMembers) {
      return const Left(ValidationFailure('Groups can have up to $maxMembers members.'));
    }
    return _repo.createGroup(
      creatorId: p.creatorId,
      creatorName: p.creatorName,
      name: name,
      memberIds: p.memberIds.toSet().where((id) => id != p.creatorId).toList(),
      description: p.description,
      photo: p.photo,
    );
  }
}

class UpdateGroup extends UseCase<void, ({String chatId, String? name, String? description, File? photo})> {
  const UpdateGroup(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(({String chatId, String? name, String? description, File? photo}) p) async {
    if (p.name != null && p.name!.trim().isEmpty) {
      return const Left(ValidationFailure('Group name cannot be empty.'));
    }
    return _repo.updateGroup(p.chatId, name: p.name?.trim(), description: p.description, photo: p.photo);
  }
}

typedef AddMembersParams = ({String chatId, List<String> uids, String actorId, String actorName, List<String> names});

class AddGroupMembers extends UseCase<void, AddMembersParams> {
  const AddGroupMembers(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(AddMembersParams p) =>
      _repo.addMembers(p.chatId, p.uids, actorId: p.actorId, actorName: p.actorName, names: p.names);
}

typedef RemoveMemberParams = ({String chatId, String uid, String actorId, String actorName, String memberName});

class RemoveGroupMember extends UseCase<void, RemoveMemberParams> {
  const RemoveGroupMember(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(RemoveMemberParams p) =>
      _repo.removeMember(p.chatId, p.uid, actorId: p.actorId, actorName: p.actorName, memberName: p.memberName);
}

class LeaveGroup extends UseCase<void, ({String chatId, String uid, String name})> {
  const LeaveGroup(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(({String chatId, String uid, String name}) p) =>
      _repo.leaveGroup(p.chatId, p.uid, name: p.name);
}

class SetGroupAdmin extends UseCase<void, ({String chatId, String uid, bool isAdmin})> {
  const SetGroupAdmin(this._repo);
  final ChatRepository _repo;
  @override
  ResultFuture<void> call(({String chatId, String uid, bool isAdmin}) p) => _repo.setAdmin(p.chatId, p.uid, p.isAdmin);
}
