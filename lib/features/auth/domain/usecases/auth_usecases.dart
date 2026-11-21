import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

class EmailCredentials {
  const EmailCredentials(this.email, this.password);
  final String email;
  final String password;
}

Failure? _validateEmail(String email) =>
    _emailRegex.hasMatch(email.trim()) ? null : const ValidationFailure('Enter a valid email address.');

class WatchAuthState extends StreamUseCase<String?, NoParams> {
  const WatchAuthState(this._repo);
  final AuthRepository _repo;
  @override
  Stream<String?> call(NoParams params) => _repo.authStateChanges();
}

class SignInWithEmail extends UseCase<void, EmailCredentials> {
  const SignInWithEmail(this._repo);
  final AuthRepository _repo;
  @override
  ResultFuture<void> call(EmailCredentials p) async {
    final invalid = _validateEmail(p.email);
    if (invalid != null) return Left(invalid);
    if (p.password.isEmpty) return const Left(ValidationFailure('Enter your password.'));
    return _repo.signInWithEmail(p.email.trim(), p.password);
  }
}

class SignUpWithEmail extends UseCase<void, EmailCredentials> {
  const SignUpWithEmail(this._repo);
  final AuthRepository _repo;
  @override
  ResultFuture<void> call(EmailCredentials p) async {
    final invalid = _validateEmail(p.email);
    if (invalid != null) return Left(invalid);
    if (p.password.length < 6) {
      return const Left(ValidationFailure('Password must be at least 6 characters.'));
    }
    return _repo.signUpWithEmail(p.email.trim(), p.password);
  }
}

class SendPasswordReset extends UseCase<void, String> {
  const SendPasswordReset(this._repo);
  final AuthRepository _repo;
  @override
  ResultFuture<void> call(String email) async {
    final invalid = _validateEmail(email);
    if (invalid != null) return Left(invalid);
    return _repo.sendPasswordReset(email.trim());
  }
}

class SendPhoneCodeParams {
  const SendPhoneCodeParams(this.phoneNumber, {this.resendToken});
  final String phoneNumber;
  final int? resendToken;
}

class SendPhoneCode extends UseCase<PhoneCodeResult, SendPhoneCodeParams> {
  const SendPhoneCode(this._repo);
  final AuthRepository _repo;
  @override
  ResultFuture<PhoneCodeResult> call(SendPhoneCodeParams p) async {
    final phone = p.phoneNumber.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
      return const Left(ValidationFailure('Enter a valid phone number.'));
    }
    return _repo.sendPhoneCode(phone, resendToken: p.resendToken);
  }
}

class VerifyPhoneCodeParams {
  const VerifyPhoneCodeParams(this.verificationId, this.code);
  final String verificationId;
  final String code;
}

class VerifyPhoneCode extends UseCase<void, VerifyPhoneCodeParams> {
  const VerifyPhoneCode(this._repo);
  final AuthRepository _repo;
  @override
  ResultFuture<void> call(VerifyPhoneCodeParams p) async {
    if (p.code.length != 6) return const Left(ValidationFailure('Enter the 6-digit code.'));
    return _repo.verifyPhoneCode(p.verificationId, p.code);
  }
}

class CurrentAccount {
  const CurrentAccount({required this.uid, this.email, this.phone});
  final String uid;
  final String? email;
  final String? phone;
}

/// Synchronous snapshot of the signed-in account's identifiers.
class GetCurrentAccount {
  const GetCurrentAccount(this._repo);
  final AuthRepository _repo;
  CurrentAccount? call() {
    final uid = _repo.currentUid;
    if (uid == null) return null;
    return CurrentAccount(uid: uid, email: _repo.currentEmail, phone: _repo.currentPhone);
  }
}

class SignOut extends UseCase<void, NoParams> {
  const SignOut(this._repo);
  final AuthRepository _repo;
  @override
  ResultFuture<void> call(NoParams p) => _repo.signOut();
}
