import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../users/domain/entities/user_entity.dart';
import '../../../domain/usecases/chat_extras.dart';
import '../../../domain/usecases/group_usecases.dart';

enum CreateGroupStep { members, details }

enum CreateGroupStatus { editing, creating, created, failure }

class CreateGroupState extends Equatable {
  const CreateGroupState({
    this.step = CreateGroupStep.members,
    this.selected = const [],
    this.emails = const [],
    this.photo,
    this.status = CreateGroupStatus.editing,
    this.chatId,
    this.error,
  });

  final CreateGroupStep step;
  final List<UserEntity> selected;

  /// People invited by email (may not have the app yet).
  final List<String> emails;
  final File? photo;
  final CreateGroupStatus status;
  final String? chatId;
  final String? error;

  bool isSelected(String uid) => selected.any((u) => u.id == uid);

  CreateGroupState copyWith({
    CreateGroupStep? step,
    List<UserEntity>? selected,
    List<String>? emails,
    File? photo,
    CreateGroupStatus? status,
    String? chatId,
    String? error,
  }) => CreateGroupState(
    step: step ?? this.step,
    selected: selected ?? this.selected,
    emails: emails ?? this.emails,
    photo: photo ?? this.photo,
    status: status ?? this.status,
    chatId: chatId ?? this.chatId,
    error: error,
  );

  @override
  List<Object?> get props => [step, selected, emails, photo?.path, status, chatId, error];
}

class CreateGroupCubit extends Cubit<CreateGroupState> {
  CreateGroupCubit(this._createGroup, this._membership, {required this.me}) : super(const CreateGroupState());

  final CreateGroup _createGroup;
  final GroupMembership _membership;
  final UserEntity me;

  void toggle(UserEntity user) {
    final selected =
        state.isSelected(user.id) ? state.selected.where((u) => u.id != user.id).toList() : [...state.selected, user];
    emit(state.copyWith(selected: selected));
  }

  void addEmails(List<String> emails) => emit(state.copyWith(emails: {...state.emails, ...emails}.toList()));

  void removeEmail(String email) => emit(state.copyWith(emails: state.emails.where((e) => e != email).toList()));

  void next() {
    if (state.selected.isEmpty && state.emails.isEmpty) {
      emit(state.copyWith(error: tr('Select at least one member or add an email.')));
      return;
    }
    emit(state.copyWith(step: CreateGroupStep.details));
  }

  void back() => emit(state.copyWith(step: CreateGroupStep.members));

  void setPhoto(File file) => emit(state.copyWith(photo: file));

  /// Name of the group just created (for the invitation email).
  String? createdName;

  Future<void> create({required String name, String? description}) async {
    createdName = name;
    emit(state.copyWith(status: CreateGroupStatus.creating));
    final result = await _createGroup(
      CreateGroupParams(
        creatorId: me.id,
        creatorName: me.name,
        name: name,
        description: description,
        memberIds: state.selected.map((u) => u.id).toList(),
        photo: state.photo,
      ),
    );
    result.match((f) => emit(state.copyWith(status: CreateGroupStatus.failure, error: f.message)), (id) async {
      if (state.emails.isNotEmpty) await _membership.inviteByEmail(id, state.emails, me.id, me.name);
      emit(state.copyWith(status: CreateGroupStatus.created, chatId: id));
    });
  }
}
