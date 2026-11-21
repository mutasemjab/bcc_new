part of 'phone_auth_bloc.dart';

sealed class PhoneAuthEvent extends Equatable {
  const PhoneAuthEvent();
  @override
  List<Object?> get props => [];
}

class PhoneCodeRequested extends PhoneAuthEvent {
  const PhoneCodeRequested(this.phone);
  final String phone;
  @override
  List<Object?> get props => [phone];
}

class PhoneCodeResendRequested extends PhoneAuthEvent {
  const PhoneCodeResendRequested();
}

class PhoneCodeSubmitted extends PhoneAuthEvent {
  const PhoneCodeSubmitted(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

class PhoneNumberEditRequested extends PhoneAuthEvent {
  const PhoneNumberEditRequested();
}
