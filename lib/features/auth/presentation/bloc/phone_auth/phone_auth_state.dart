part of 'phone_auth_bloc.dart';

enum PhoneAuthStatus { idle, loading, failure, codeSent, verifying, codeError, verified }

class PhoneAuthState extends Equatable {
  const PhoneAuthState({
    this.status = PhoneAuthStatus.idle,
    this.phone,
    this.verificationId,
    this.resendToken,
    this.codeSentAt,
    this.message,
  });

  final PhoneAuthStatus status;
  final String? phone;
  final String? verificationId;
  final int? resendToken;
  final DateTime? codeSentAt;
  final String? message;

  bool get isCodeStep => verificationId != null;
  bool get isBusy => status == PhoneAuthStatus.loading || status == PhoneAuthStatus.verifying;

  PhoneAuthState copyWith({
    PhoneAuthStatus? status,
    String? phone,
    String? verificationId,
    int? resendToken,
    DateTime? codeSentAt,
    String? message,
  }) => PhoneAuthState(
    status: status ?? this.status,
    phone: phone ?? this.phone,
    verificationId: verificationId ?? this.verificationId,
    resendToken: resendToken ?? this.resendToken,
    codeSentAt: codeSentAt ?? this.codeSentAt,
    message: message,
  );

  @override
  List<Object?> get props => [status, phone, verificationId, resendToken, codeSentAt, message];
}
