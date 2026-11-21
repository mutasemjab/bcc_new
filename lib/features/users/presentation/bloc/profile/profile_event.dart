part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class ProfileLoaded extends ProfileEvent {
  const ProfileLoaded();
}

class ProfileAvatarPicked extends ProfileEvent {
  const ProfileAvatarPicked(this.file);
  final File file;
  @override
  List<Object?> get props => [file.path];
}

class ProfileSubmitted extends ProfileEvent {
  const ProfileSubmitted({required this.name, required this.about});
  final String name;
  final String about;
  @override
  List<Object?> get props => [name, about];
}
