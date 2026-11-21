import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../auth/domain/usecases/auth_usecases.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/user_usecases.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// Creates (first run) or edits the signed-in user's profile.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required GetCurrentAccount getCurrentAccount,
    required GetUser getUser,
    required SaveProfile saveProfile,
  }) : _getCurrentAccount = getCurrentAccount,
       _getUser = getUser,
       _saveProfile = saveProfile,
       super(const ProfileState()) {
    on<ProfileLoaded>(_onLoaded);
    on<ProfileAvatarPicked>((e, emit) => emit(state.copyWith(avatar: e.file)));
    on<ProfileSubmitted>(_onSubmitted);
  }

  final GetCurrentAccount _getCurrentAccount;
  final GetUser _getUser;
  final SaveProfile _saveProfile;

  Future<void> _onLoaded(ProfileLoaded e, Emitter<ProfileState> emit) async {
    final account = _getCurrentAccount();
    if (account == null) return;
    final result = await _getUser(account.uid);
    result.match(
      (_) => emit(state.copyWith(status: ProfileStatus.ready)),
      (user) => emit(state.copyWith(status: ProfileStatus.ready, user: user)),
    );
  }

  Future<void> _onSubmitted(ProfileSubmitted e, Emitter<ProfileState> emit) async {
    final account = _getCurrentAccount();
    if (account == null) return;
    emit(state.copyWith(status: ProfileStatus.saving));
    final result = await _saveProfile(
      SaveProfileParams(
        uid: account.uid,
        name: e.name,
        about: e.about,
        avatar: state.avatar,
        email: account.email,
        phone: account.phone,
      ),
    );
    result.match(
      (f) => emit(state.copyWith(status: ProfileStatus.failure, message: f.message)),
      (user) => emit(state.copyWith(status: ProfileStatus.saved, user: user)),
    );
  }
}
