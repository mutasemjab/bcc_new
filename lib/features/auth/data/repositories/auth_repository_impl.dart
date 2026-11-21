import '../../../../core/error/error_mapper.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  final AuthRemoteDataSource _remote;

  @override
  Stream<String?> authStateChanges() => _remote.authStateChanges();

  @override
  String? get currentUid => _remote.currentUser?.uid;

  @override
  String? get currentEmail => _remote.currentUser?.email;

  @override
  String? get currentPhone => _remote.currentUser?.phoneNumber;

  @override
  ResultFuture<void> signInWithEmail(String email, String password) =>
      guard(() => _remote.signInWithEmail(email, password));

  @override
  ResultFuture<void> signUpWithEmail(String email, String password) =>
      guard(() => _remote.signUpWithEmail(email, password));

  @override
  ResultFuture<void> sendPasswordReset(String email) => guard(() => _remote.sendPasswordReset(email));

  @override
  ResultFuture<PhoneCodeResult> sendPhoneCode(String phoneNumber, {int? resendToken}) =>
      guard(() => _remote.sendPhoneCode(phoneNumber, resendToken: resendToken));

  @override
  ResultFuture<void> verifyPhoneCode(String verificationId, String smsCode) =>
      guard(() => _remote.verifyPhoneCode(verificationId, smsCode));

  @override
  ResultFuture<void> signOut() => guard(_remote.signOut);
}
