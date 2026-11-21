import '../../../../core/usecase/usecase.dart';

/// Result of requesting an SMS code.
sealed class PhoneCodeResult {
  const PhoneCodeResult();
}

/// The code was sent; the user must type it.
class PhoneCodeSent extends PhoneCodeResult {
  const PhoneCodeSent(this.verificationId, this.resendToken);
  final String verificationId;
  final int? resendToken;
}

/// Android auto-retrieved the SMS and the user is already signed in.
class PhoneAutoVerified extends PhoneCodeResult {
  const PhoneAutoVerified();
}

abstract interface class AuthRepository {
  /// Emits the signed-in uid, or null when signed out.
  Stream<String?> authStateChanges();
  String? get currentUid;
  String? get currentEmail;
  String? get currentPhone;

  ResultFuture<void> signInWithEmail(String email, String password);
  ResultFuture<void> signUpWithEmail(String email, String password);
  ResultFuture<void> sendPasswordReset(String email);

  ResultFuture<PhoneCodeResult> sendPhoneCode(String phoneNumber, {int? resendToken});
  ResultFuture<void> verifyPhoneCode(String verificationId, String smsCode);

  ResultFuture<void> signOut();
}
