part of 'session_bloc.dart';

sealed class SessionState extends Equatable {
  const SessionState();
  @override
  List<Object?> get props => [];
}

class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

/// Signed in but the profile (name/photo) is not set up yet.
class SessionNeedsProfile extends SessionState {
  const SessionNeedsProfile(this.uid);
  final String uid;
  @override
  List<Object?> get props => [uid];
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final UserEntity user;
  @override
  List<Object?> get props => [user];
}
