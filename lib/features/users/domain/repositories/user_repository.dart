import 'dart:io';

import '../../../../core/usecase/usecase.dart';
import '../entities/user_entity.dart';

abstract interface class UserRepository {
  /// Live profile of a single user (null when the doc does not exist yet).
  Stream<UserEntity?> watchUser(String uid);

  /// Live profiles for a set of users (handles Firestore's `in` limits).
  Stream<Map<String, UserEntity>> watchUsers(Set<String> uids);

  ResultFuture<UserEntity?> getUser(String uid);

  ResultFuture<UserEntity> saveProfile({
    required String uid,
    required String name,
    required String about,
    File? avatar,
    String? email,
    String? phone,
  });

  /// Search by exact email, exact phone or name prefix.
  ResultFuture<List<UserEntity>> search(String query, {required String excludeUid});

  /// Registered users whose phone is in [phones] (international format).
  ResultFuture<List<UserEntity>> findByPhones(List<String> phones, {required String excludeUid});

  ResultFuture<void> setPresence(String uid, {required bool online});

  ResultFuture<void> registerPushToken(String uid, String token);
  ResultFuture<void> removePushToken(String uid, String token);

  ResultFuture<void> updatePrivacy(String uid, {bool? hideLastSeen, bool? hideOnline, bool? readReceipts});
  Stream<Set<String>> watchBlocked(String uid);
  ResultFuture<void> setBlocked(String uid, String other, {required bool blocked});
}
