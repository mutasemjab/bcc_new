import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/auth_usecases.dart';

part 'email_auth_event.dart';
part 'email_auth_state.dart';

class EmailAuthBloc extends Bloc<EmailAuthEvent, EmailAuthState> {
  EmailAuthBloc({
    required SignInWithEmail signIn,
    required SignUpWithEmail signUp,
    required SendPasswordReset sendReset,
  }) : _signIn = signIn,
       _signUp = signUp,
       _sendReset = sendReset,
       super(const EmailAuthState()) {
    on<EmailAuthModeToggled>((e, emit) => emit(EmailAuthState(isSignUp: !state.isSignUp)));
    on<EmailAuthSubmitted>(_onSubmitted);
    on<PasswordResetRequested>(_onReset);
  }

  final SignInWithEmail _signIn;
  final SignUpWithEmail _signUp;
  final SendPasswordReset _sendReset;

  Future<void> _onSubmitted(EmailAuthSubmitted e, Emitter<EmailAuthState> emit) async {
    emit(state.copyWith(status: EmailAuthStatus.loading));
    final creds = EmailCredentials(e.email, e.password);
    final result = state.isSignUp ? await _signUp(creds) : await _signIn(creds);
    result.match(
      (f) => emit(state.copyWith(status: EmailAuthStatus.failure, message: f.message)),
      // Navigation is driven by SessionBloc reacting to the auth stream.
      (_) => emit(state.copyWith(status: EmailAuthStatus.success)),
    );
  }

  Future<void> _onReset(PasswordResetRequested e, Emitter<EmailAuthState> emit) async {
    emit(state.copyWith(status: EmailAuthStatus.loading));
    final result = await _sendReset(e.email);
    result.match(
      (f) => emit(state.copyWith(status: EmailAuthStatus.failure, message: f.message)),
      (_) => emit(
        state.copyWith(status: EmailAuthStatus.resetSent, message: 'Password reset link sent to ${e.email.trim()}'),
      ),
    );
  }
}
