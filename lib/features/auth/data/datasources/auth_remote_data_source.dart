import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide PhoneCodeSent;

import '../../domain/repositories/auth_repository.dart';

abstract interface class AuthRemoteDataSource {
  Stream<String?> authStateChanges();
  User? get currentUser;
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<PhoneCodeResult> sendPhoneCode(String phone, {int? resendToken});
  Future<void> verifyPhoneCode(String verificationId, String smsCode);
  Future<void> signOut();
}

class FirebaseAuthDataSource implements AuthRemoteDataSource {
  FirebaseAuthDataSource(this._auth);
  final FirebaseAuth _auth;

  @override
  Stream<String?> authStateChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signUpWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email);

  /// Bridges Firebase's callback-based API into a single Future.
  @override
  Future<PhoneCodeResult> sendPhoneCode(String phone, {int? resendToken}) {
    final completer = Completer<PhoneCodeResult>();
    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android instant verification / SMS auto-retrieval.
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete(const PhoneAutoVerified());
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, token) {
        if (!completer.isCompleted) completer.complete(PhoneCodeSent(verificationId, token));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  @override
  Future<void> verifyPhoneCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
