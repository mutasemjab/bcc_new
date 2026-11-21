part of 'email_auth_bloc.dart';

enum EmailAuthStatus { idle, loading, success, failure, resetSent }

class EmailAuthState extends Equatable {
  const EmailAuthState({this.isSignUp = false, this.status = EmailAuthStatus.idle, this.message});

  final bool isSignUp;
  final EmailAuthStatus status;
  final String? message;

  bool get isLoading => status == EmailAuthStatus.loading;

  EmailAuthState copyWith({EmailAuthStatus? status, String? message}) =>
      EmailAuthState(isSignUp: isSignUp, status: status ?? this.status, message: message);

  @override
  List<Object?> get props => [isSignUp, status, message];
}
