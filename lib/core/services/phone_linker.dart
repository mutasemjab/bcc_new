import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/firestore_paths.dart';
import '../error/error_mapper.dart';

/// Adds a *verified* phone number to an account that signed up with email,
/// so friends who saved that number can find it (like WhatsApp).
///
/// The number is proven with an SMS code and linked to the sign-in account;
/// the security rules only accept a profile phone equal to that verified one.
class PhoneLinker {
  PhoneLinker(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Sends the SMS code. Returns the verification id, or null when Android
  /// verified the number automatically (already linked).
  Future<String?> sendCode(String phone) {
    final completer = Completer<String?>();
    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await _link(credential);
          if (!completer.isCompleted) completer.complete(null);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(_friendly(e));
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(_friendly(e));
      },
      codeSent: (id, _) {
        if (!completer.isCompleted) completer.complete(id);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  Future<void> confirmCode(String verificationId, String code) async {
    try {
      await _link(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));
    } catch (e) {
      throw _friendly(e);
    }
  }

  Future<void> _link(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) throw 'You are signed out.';
    if (user.phoneNumber == null) {
      await user.linkWithCredential(credential);
    } else {
      await user.updatePhoneNumber(credential); // replacing an existing number
    }
    await user.reload();
    await user.getIdToken(true); // the rules read the new number from the token
    final phone = _auth.currentUser?.phoneNumber;
    if (phone == null) throw 'Could not verify this number.';
    await _db.collection(FirestorePaths.users).doc(user.uid).set({'phone': phone}, SetOptions(merge: true));
  }

  static String _friendly(Object e) {
    if (e is FirebaseAuthException) {
      if (e.code == 'credential-already-in-use' || e.code == 'account-exists-with-different-credential') {
        return 'This number is already used by another account.';
      }
      if (e.code == 'provider-already-linked') return 'A phone number is already linked to this account.';
      return mapError(e).message;
    }
    return e is String ? e : 'Could not verify this number.';
  }
}
