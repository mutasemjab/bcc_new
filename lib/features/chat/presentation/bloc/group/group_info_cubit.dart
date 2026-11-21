import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/usecase/usecase.dart';
import '../../../../users/domain/entities/user_entity.dart';
import '../../../../users/domain/usecases/user_usecases.dart';
import '../../../domain/entities/chat_entity.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../../domain/usecases/chat_extras.dart';
import '../../../domain/usecases/chat_usecases.dart';
import '../../../domain/usecases/group_usecases.dart';

class GroupInfoState extends Equatable {
  const GroupInfoState({this.chat, this.members = const {}, this.busy = false, this.message, this.left = false});
  final ChatEntity? chat;
  final Map<String, UserEntity> members;
  final bool busy;
  final String? message;
  final bool left;

  /// Anonymous members are masked: alias as name, no photo, phone or presence.
  UserEntity? displayUser(String uid) {
    final u = members[uid];
    final alias = chat?.aliasOf(uid);
    if (alias == null) return u;
    return UserEntity(id: uid, name: alias, about: 'Anonymous member');
  }

  Map<String, UserEntity> get displayMembers => {
    for (final id in members.keys)
      if (displayUser(id) != null) id: displayUser(id)!,
  };

  List<UserEntity> invitedUsers() =>
      (chat?.invited ?? const <String>[]).map(displayUser).whereType<UserEntity>().toList();

  List<UserEntity> sortedMembers() {
    final c = chat;
    if (c == null) return const [];
    final list = c.participants.map(displayUser).whereType<UserEntity>().toList();
    list.sort((a, b) {
      final aa = c.isAdmin(a.id), ba = c.isAdmin(b.id);
      if (aa != ba) return aa ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  GroupInfoState copyWith({
    ChatEntity? chat,
    Map<String, UserEntity>? members,
    bool? busy,
    String? message,
    bool? left,
  }) => GroupInfoState(
    chat: chat ?? this.chat,
    members: members ?? this.members,
    busy: busy ?? this.busy,
    message: message,
    left: left ?? this.left,
  );

  @override
  List<Object?> get props => [chat, members, busy, message, left];
}

/// Group details & admin actions.
class GroupInfoCubit extends Cubit<GroupInfoState> {
  GroupInfoCubit({
    required this.chatId,
    required this.me,
    required WatchChat watchChat,
    required WatchUsers watchUsers,
    required UpdateGroup updateGroup,
    required AddGroupMembers addMembers,
    required RemoveGroupMember removeMember,
    required LeaveGroup leaveGroup,
    required SetGroupAdmin setAdmin,
    required GroupMembership membership,
  }) : _watchUsers = watchUsers,
       _updateGroup = updateGroup,
       _addMembers = addMembers,
       _removeMember = removeMember,
       _leaveGroup = leaveGroup,
       _setAdmin = setAdmin,
       _membership = membership,
       super(const GroupInfoState()) {
    _chatSub = watchChat(chatId).listen(_onChat);
  }

  final String chatId;
  final UserEntity me;
  final WatchUsers _watchUsers;
  final UpdateGroup _updateGroup;
  final AddGroupMembers _addMembers;
  final RemoveGroupMember _removeMember;
  final LeaveGroup _leaveGroup;
  final SetGroupAdmin _setAdmin;
  final GroupMembership _membership;

  StreamSubscription<ChatEntity?>? _chatSub;
  StreamSubscription<Map<String, UserEntity>>? _usersSub;
  Set<String> _watched = {};

  bool get isAdmin => state.chat?.isAdmin(me.id) ?? false;

  /// How I appear in this group (alias when anonymous).
  String get myDisplayName => state.chat?.aliasOf(me.id) ?? me.name;

  void _onChat(ChatEntity? chat) {
    if (chat == null || isClosed) return;
    emit(state.copyWith(chat: chat));
    final ids = {...chat.participants, ...chat.invited};
    if (ids.length != _watched.length || !ids.containsAll(_watched)) {
      _watched = ids;
      _usersSub?.cancel();
      _usersSub = _watchUsers(ids).listen((u) {
        if (!isClosed) emit(state.copyWith(members: {...u, me.id: me}));
      });
    }
  }

  Future<void> _run(ResultFuture<void> Function() action, {String? success}) async {
    emit(state.copyWith(busy: true));
    final r = await action();
    r.match(
      (f) => emit(state.copyWith(busy: false, message: f.message)),
      (_) => emit(state.copyWith(busy: false, message: success)),
    );
  }

  Future<void> rename(String name) =>
      _run(() => _updateGroup((chatId: chatId, name: name, description: null, photo: null)));

  Future<void> setDescription(String d) =>
      _run(() => _updateGroup((chatId: chatId, name: null, description: d, photo: null)));

  Future<void> setPhoto(File f) =>
      _run(() => _updateGroup((chatId: chatId, name: null, description: null, photo: f)), success: 'Photo updated');

  Future<void> addMembers(List<UserEntity> users) => _run(
    () => _addMembers((
      chatId: chatId,
      uids: users.map((u) => u.id).toList(),
      actorId: me.id,
      actorName: myDisplayName,
      names: users.map((u) => u.name).toList(),
    )),
  );

  Future<void> remove(UserEntity user) => _run(
    () =>
        _removeMember((chatId: chatId, uid: user.id, actorId: me.id, actorName: myDisplayName, memberName: user.name)),
  );

  Future<void> toggleAdmin(UserEntity user) {
    final makeAdmin = !(state.chat?.isAdmin(user.id) ?? false);
    return _run(() => _setAdmin((chatId: chatId, uid: user.id, isAdmin: makeAdmin)));
  }

  Future<void> leave() async {
    emit(state.copyWith(busy: true));
    final r = await _leaveGroup((chatId: chatId, uid: me.id, name: myDisplayName));
    r.match(
      (f) => emit(state.copyWith(busy: false, message: f.message)),
      (_) => emit(state.copyWith(busy: false, left: true)),
    );
  }

  // ── Identity ──

  Future<void> revealIdentity() async {
    final chat = state.chat;
    if (chat == null) return;
    await _run(() => _membership.reveal(chat, me.id, me.name), success: 'Your identity is now visible');
  }

  Future<void> hideIdentity() async {
    final chat = state.chat;
    if (chat == null) return;
    await _run(
      () => _membership.hide(chat, me.id, me.name, IdUtils.anonymousAlias()),
      success: 'You are now anonymous in this group',
    );
  }

  // ── Invitations & link ──

  Future<void> cancelInvite(UserEntity user) =>
      _run(() => _membership.cancelInvite(chatId, user.id), success: 'Invitation cancelled');

  /// Returns the link code (creating one if needed).
  Future<String?> ensureInviteCode({bool reset = false}) async {
    final existing = state.chat?.inviteCode;
    if (existing != null && !reset) return existing;
    final r = await _membership.createLink(chatId);
    return r.fold((f) {
      emit(state.copyWith(message: f.message));
      return null;
    }, (code) => code);
  }

  Future<void> revokeLink() async {
    final code = state.chat?.inviteCode;
    if (code == null) return;
    await _run(() => _membership.revokeLink(chatId, code), success: 'Invite link turned off');
  }

  @override
  Future<void> close() async {
    await _chatSub?.cancel();
    await _usersSub?.cancel();
    return super.close();
  }
}
