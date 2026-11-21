part of 'email_auth_bloc.dart';

sealed class EmailAuthEvent extends Equatable {
  const EmailAuthEvent();
  @override
  List<Object?> get props => [];
}

class EmailAuthModeToggled extends EmailAuthEvent {
  const EmailAuthModeToggled();
}

class EmailAuthSubmitted extends EmailAuthEvent {
  const EmailAuthSubmitted(this.email, this.password);
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class PasswordResetRequested extends EmailAuthEvent {
  const PasswordResetRequested(this.email);
  final String email;
  @override
  List<Object?> get props => [email];
}
