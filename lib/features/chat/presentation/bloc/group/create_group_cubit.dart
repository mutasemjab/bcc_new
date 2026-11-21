import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../users/domain/entities/user_entity.dart';
import '../../../domain/usecases/group_usecases.dart';

enum CreateGroupStep { members, details }

enum CreateGroupStatus { editing, creating, created, failure }

class CreateGroupState extends Equatable {
  const CreateGroupState({
    this.step = CreateGroupStep.members,
    this.selected = const [],
    this.photo,
    this.status = CreateGroupStatus.editing,
    this.chatId,
    this.error,
  });

  final CreateGroupStep step;
  final List<UserEntity> selected;
  final File? photo;
  final CreateGroupStatus status;
  final String? chatId;
  final String? error;

  bool isSelected(String uid) => selected.any((u) => u.id == uid);

  CreateGroupState copyWith({
    CreateGroupStep? step,
    List<UserEntity>? selected,
    File? photo,
    CreateGroupStatus? status,
    String? chatId,
    String? error,
  }) => CreateGroupState(
    step: step ?? this.step,
    selected: selected ?? this.selected,
    photo: photo ?? this.photo,
    status: status ?? this.status,
    chatId: chatId ?? this.chatId,
    error: error,
  );

  @override
  List<Object?> get props => [step, selected, photo?.path, status, chatId, error];
}

class CreateGroupCubit extends Cubit<CreateGroupState> {
  CreateGroupCubit(this._createGroup, {required this.me}) : super(const CreateGroupState());

  final CreateGroup _createGroup;
  final UserEntity me;

  void toggle(UserEntity user) {
    final selected =
        state.isSelected(user.id) ? state.selected.where((u) => u.id != user.id).toList() : [...state.selected, user];
    emit(state.copyWith(selected: selected));
  }

  void next() {
    if (state.selected.isEmpty) {
      emit(state.copyWith(error: 'Select at least one member.'));
      return;
    }
    emit(state.copyWith(step: CreateGroupStep.details));
  }

  void back() => emit(state.copyWith(step: CreateGroupStep.members));

  void setPhoto(File file) => emit(state.copyWith(photo: file));

  Future<void> create({required String name, String? description}) async {
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
    result.match(
      (f) => emit(state.copyWith(status: CreateGroupStatus.failure, error: f.message)),
      (id) => emit(state.copyWith(status: CreateGroupStatus.created, chatId: id)),
    );
  }
}
