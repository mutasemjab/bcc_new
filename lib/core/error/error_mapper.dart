import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fpdart/fpdart.dart';

import 'failures.dart';

/// Runs [action] and maps any thrown error into a [Failure].
Future<Either<Failure, T>> guard<T>(Future<T> Function() action) async {
  try {
    return Right(await action());
  } catch (e) {
    return Left(mapError(e));
  }
}

Failure mapError(Object error) {
  if (error is Failure) return error;
  if (error is FirebaseAuthException) return AuthFailure(_authMessage(error));
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return const PermissionFailure();
      case 'unavailable':
        return const NetworkFailure();
      case 'not-found':
      case 'object-not-found':
        return const NotFoundFailure();
      default:
        return const ServerFailure('Something went wrong. Please try again.');
    }
  }
  return const ServerFailure();
}

String _authMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'weak-password':
      return 'Choose a stronger password (at least 6 characters).';
    case 'invalid-phone-number':
      return 'That phone number is not valid.';
    case 'invalid-verification-code':
      return 'The code you entered is incorrect.';
    case 'session-expired':
      return 'The code expired. Please request a new one.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait and try again.';
    case 'network-request-failed':
      return 'No internet connection.';
    // ── Phone sign-in setup problems (show the real cause) ──
    case 'operation-not-allowed':
      return 'Phone sign-in is not enabled for this app yet. (operation-not-allowed)';
    case 'app-not-authorized':
    case 'invalid-app-credential':
    case 'missing-client-identifier':
    case 'captcha-check-failed':
      return 'This app build could not be verified for phone sign-in. Check the SHA-1/SHA-256 '
          'fingerprints and that the Play Integrity API is enabled. (${e.code})';
    case 'quota-exceeded':
      return 'Too many SMS codes were sent today. Please try again later. (quota-exceeded)';
    case 'billing-not-enabled':
      return 'SMS sign-in needs billing enabled on the server project. (billing-not-enabled)';
    case 'web-context-cancelled':
      return 'Verification was cancelled. Please try again.';
    default:
      final detail = (e.message ?? '').toLowerCase();
      if (detail.contains('billing')) {
        return 'SMS sign-in needs billing enabled on the server project. (${e.code})';
      }
      return 'Sign-in failed (${e.code}). Please try again.';
  }
}
