part of 'session_bloc.dart';

sealed class SessionEvent extends Equatable {
  const SessionEvent();
  @override
  List<Object?> get props => [];
}

class SessionStarted extends SessionEvent {
  const SessionStarted();
}

class SessionForegroundChanged extends SessionEvent {
  const SessionForegroundChanged(this.foreground);
  final bool foreground;
  @override
  List<Object?> get props => [foreground];
}

class SessionSignOutRequested extends SessionEvent {
  const SessionSignOutRequested();
}

class _AuthUidChanged extends SessionEvent {
  const _AuthUidChanged(this.uid);
  final String? uid;
  @override
  List<Object?> get props => [uid];
}

class _ProfileChanged extends SessionEvent {
  const _ProfileChanged(this.uid, this.user);
  final String uid;
  final UserEntity? user;
  @override
  List<Object?> get props => [uid, user];
}
