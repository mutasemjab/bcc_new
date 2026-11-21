import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';

part 'phone_auth_event.dart';
part 'phone_auth_state.dart';

class PhoneAuthBloc extends Bloc<PhoneAuthEvent, PhoneAuthState> {
  PhoneAuthBloc({required SendPhoneCode sendCode, required VerifyPhoneCode verifyCode})
    : _sendCode = sendCode,
      _verifyCode = verifyCode,
      super(const PhoneAuthState()) {
    on<PhoneCodeRequested>(_onRequested);
    on<PhoneCodeResendRequested>(_onResend);
    on<PhoneCodeSubmitted>(_onSubmitted);
    on<PhoneNumberEditRequested>((e, emit) => emit(const PhoneAuthState()));
  }

  final SendPhoneCode _sendCode;
  final VerifyPhoneCode _verifyCode;

  Future<void> _onRequested(PhoneCodeRequested e, Emitter<PhoneAuthState> emit) async {
    emit(state.copyWith(status: PhoneAuthStatus.loading, phone: e.phone));
    await _request(e.phone, null, emit);
  }

  Future<void> _onResend(PhoneCodeResendRequested e, Emitter<PhoneAuthState> emit) async {
    if (state.phone == null) return;
    emit(state.copyWith(status: PhoneAuthStatus.loading));
    await _request(state.phone!, state.resendToken, emit);
  }

  Future<void> _request(String phone, int? resendToken, Emitter<PhoneAuthState> emit) async {
    final result = await _sendCode(SendPhoneCodeParams(phone, resendToken: resendToken));
    result.match((f) => emit(state.copyWith(status: PhoneAuthStatus.failure, message: f.message)), (r) {
      switch (r) {
        case PhoneCodeSent(:final verificationId, :final resendToken):
          emit(
            state.copyWith(
              status: PhoneAuthStatus.codeSent,
              verificationId: verificationId,
              resendToken: resendToken,
              codeSentAt: DateTime.now(),
            ),
          );
        case PhoneAutoVerified():
          emit(state.copyWith(status: PhoneAuthStatus.verified));
      }
    });
  }

  Future<void> _onSubmitted(PhoneCodeSubmitted e, Emitter<PhoneAuthState> emit) async {
    final id = state.verificationId;
    if (id == null) return;
    emit(state.copyWith(status: PhoneAuthStatus.verifying));
    final result = await _verifyCode(VerifyPhoneCodeParams(id, e.code));
    result.match(
      (f) => emit(state.copyWith(status: PhoneAuthStatus.codeError, message: f.message)),
      (_) => emit(state.copyWith(status: PhoneAuthStatus.verified)),
    );
  }
}
