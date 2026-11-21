part of 'profile_bloc.dart';

enum ProfileStatus { loading, ready, saving, saved, failure }

class ProfileState extends Equatable {
  const ProfileState({this.status = ProfileStatus.loading, this.user, this.avatar, this.message});

  final ProfileStatus status;
  final UserEntity? user;
  final File? avatar;
  final String? message;

  ProfileState copyWith({ProfileStatus? status, UserEntity? user, File? avatar, String? message}) => ProfileState(
    status: status ?? this.status,
    user: user ?? this.user,
    avatar: avatar ?? this.avatar,
    message: message,
  );

  @override
  List<Object?> get props => [status, user, avatar?.path, message];
}
