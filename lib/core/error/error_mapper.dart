import 'package:bcc_chat/core/l10n/l10n.dart';
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
        return ServerFailure(tr('Something went wrong. Please try again.'));
    }
  }
  return const ServerFailure();
}

String _authMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return tr('That email address looks invalid.');
    case 'user-disabled':
      return tr('This account has been disabled.');
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return tr('Incorrect email or password.');
    case 'email-already-in-use':
      return tr('An account already exists with this email.');
    case 'weak-password':
      return tr('Choose a stronger password (at least 6 characters).');
    case 'invalid-phone-number':
      return tr('That phone number is not valid.');
    case 'invalid-verification-code':
      return tr('The code you entered is incorrect.');
    case 'session-expired':
      return tr('The code expired. Please request a new one.');
    case 'too-many-requests':
      return tr('Too many attempts. Please wait and try again.');
    case 'network-request-failed':
      return tr('No internet connection.');
    // ── Phone sign-in setup problems (show the real cause) ──
    case 'operation-not-allowed':
      return tr('Phone sign-in is not enabled for this app yet. (operation-not-allowed)');
    case 'app-not-authorized':
    case 'invalid-app-credential':
    case 'missing-client-identifier':
    case 'captcha-check-failed':
      return tr(
        'This app build could not be verified for phone sign-in. Check the SHA-1/SHA-256 fingerprints and that the Play Integrity API is enabled. ({0})',
        [e.code],
      );
    case 'quota-exceeded':
      return tr('Too many SMS codes were sent today. Please try again later. (quota-exceeded)');
    case 'billing-not-enabled':
      return tr('SMS sign-in needs billing enabled on the server project. (billing-not-enabled)');
    case 'web-context-cancelled':
      return tr('Verification was cancelled. Please try again.');
    default:
      final detail = (e.message ?? '').toLowerCase();
      if (detail.contains('billing')) {
        return tr('SMS sign-in needs billing enabled on the server project. ({0})', [e.code]);
      }
      return tr('Sign-in failed ({0}). Please try again.', [e.code]);
  }
}
