import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/data/storage_data_source.dart';
import '../../../../core/services/contacts_service.dart';
import '../models/user_model.dart';

abstract interface class UserRemoteDataSource {
  Stream<UserModel?> watchUser(String uid);
  Stream<Map<String, UserModel>> watchUsers(Set<String> uids);
  Future<UserModel?> getUser(String uid);
  Future<UserModel> saveProfile({
    required String uid,
    required String name,
    required String about,
    File? avatar,
    String? email,
    String? phone,
  });
  Future<List<UserModel>> search(String query, String excludeUid);
  Future<List<UserModel>> findByPhones(List<String> phones, String excludeUid);
  Future<void> setPresence(String uid, bool online);
  Future<void> updateTokens(String uid, String token, {required bool add});

  // Privacy & blocking
  Future<void> updatePrivacy(String uid, {bool? hideLastSeen, bool? hideOnline, bool? readReceipts});
  Stream<Set<String>> watchBlocked(String uid);
  Future<void> setBlocked(String uid, String other, {required bool blocked});
}

class FirestoreUserDataSource implements UserRemoteDataSource {
  FirestoreUserDataSource(this._db, this._storage);
  final FirebaseFirestore _db;
  final StorageDataSource _storage;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection(FirestorePaths.users);
  CollectionReference<Map<String, dynamic>> get _presence => _db.collection(FirestorePaths.presence);

  /// Online / last seen of [uid]. Reading is denied by the security rules if
  /// that user blocked me — which simply looks like "hidden".
  Stream<({bool online, DateTime? lastSeen})> _presenceOf(String uid) => Rx.combineLatest2(
        _presence.doc(uid).snapshots(),
        // Re-check every 30 s: a killed app sends no update, it just goes stale.
        Stream<int>.periodic(const Duration(seconds: 30), (i) => i).startWith(0),
        (DocumentSnapshot<Map<String, dynamic>> d, int _) => d,
      )
      .map<({bool online, DateTime? lastSeen})>((d) {
        final data = d.data() ?? const <String, dynamic>{};
        final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
        final beat = (data['heartbeatAt'] as Timestamp?)?.toDate();
        // A killed app can't say "offline". Online only counts while the app
        // keeps sending heartbeats (every minute) — stale for 2 min = offline.
        final fresh = beat != null && DateTime.now().difference(beat) < const Duration(minutes: 2);
        final online = data['online'] == true && fresh;
        // When it went stale, the last heartbeat is the real "last seen"
        // (only if the user shares last seen at all).
        final seen = lastSeen == null || beat == null ? lastSeen : (beat.isAfter(lastSeen) ? beat : lastSeen);
        return (online: online, lastSeen: seen);
      })
      .onErrorReturn((online: false, lastSeen: null));

  @override
  Stream<UserModel?> watchUser(String uid) => Rx.combineLatest2(
    _users.doc(uid).snapshots().map((d) => d.exists ? UserModel.fromDoc(d) : null),
    _presenceOf(uid),
    (UserModel? u, p) => u?.withLivePresence(online: p.online, lastSeen: p.lastSeen),
  );

  @override
  Stream<Map<String, UserModel>> watchUsers(Set<String> uids) {
    if (uids.isEmpty) return Stream.value(const {});
    final ids = uids.toList();
    // Firestore `whereIn` accepts at most 30 values → chunk and merge.
    final chunks = <List<String>>[
      for (var i = 0; i < ids.length; i += 30) ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30),
    ];
    final streams = chunks.map(
      (c) => _users
          .where(FieldPath.documentId, whereIn: c)
          .snapshots()
          .map((s) => {for (final d in s.docs) d.id: UserModel.fromDoc(d)}),
    );
    final profiles = Rx.combineLatestList(streams).map((maps) => {for (final m in maps) ...m});
    // Presence docs are read one by one (the block check is per user).
    final presence = Rx.combineLatestList(
      ids.map((id) => _presenceOf(id).map((p) => MapEntry(id, p))),
    ).map(Map.fromEntries);
    return Rx.combineLatest2(profiles, presence, (
      Map<String, UserModel> users,
      Map<String, ({bool online, DateTime? lastSeen})> pres,
    ) {
      return {
        for (final e in users.entries)
          e.key: e.value.withLivePresence(online: pres[e.key]?.online ?? false, lastSeen: pres[e.key]?.lastSeen),
      };
    });
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    final d = await _users.doc(uid).get();
    return d.exists ? UserModel.fromDoc(d) : null;
  }

  @override
  Future<UserModel> saveProfile({
    required String uid,
    required String name,
    required String about,
    File? avatar,
    String? email,
    String? phone,
  }) async {
    String? photoUrl;
    if (avatar != null) {
      photoUrl = await _storage.uploadFile(file: avatar, path: StoragePaths.avatar(uid), contentType: 'image/jpeg');
    }
    final ref = _users.doc(uid);
    final exists = (await ref.get()).exists;
    await ref.set({
      ...UserModel.profileFields(name: name, about: about, photoUrl: photoUrl, email: email, phone: phone),
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!exists) 'isOnline': true,
    }, SetOptions(merge: true));
    return UserModel.fromDoc(await ref.get());
  }

  @override
  Future<List<UserModel>> search(String query, String excludeUid) async {
    final q = query.trim();
    final results = <String, UserModel>{};

    Future<void> add(Query<Map<String, dynamic>> query) async {
      final snap = await query.limit(20).get();
      for (final d in snap.docs) {
        if (d.id != excludeUid) results[d.id] = UserModel.fromDoc(d);
      }
    }

    if (q.contains('@')) {
      await add(_users.where('email', isEqualTo: q.toLowerCase()));
    } else if (RegExp(r'^[+0-9 ()-]{6,}$').hasMatch(q)) {
      // Accept any written form: 079 123 4567, 0791234567, 00962…, +962…
      final normalized = PhoneNumbers.normalize(q, PhoneNumbers.fallbackCountryCode);
      if (normalized != null) await add(_users.where('phone', isEqualTo: normalized));
    } else {
      final lower = q.toLowerCase();
      await add(_users.orderBy('nameLower').startAt([lower]).endAt(['$lower']));
    }
    return results.values.toList();
  }

  @override
  Future<List<UserModel>> findByPhones(List<String> phones, String excludeUid) async {
    final unique = phones.toSet().toList();
    // `whereIn` takes at most 30 values per query. Run a limited number of
    // queries at a time so 10,000 contacts don't fire 400 requests at once.
    final chunks = [
      for (var i = 0; i < unique.length; i += 30) unique.sublist(i, i + 30 > unique.length ? unique.length : i + 30),
    ];
    final results = <UserModel>[];
    var next = 0;
    Future<void> worker() async {
      while (next < chunks.length) {
        final chunk = chunks[next++];
        final snap = await _users.where('phone', whereIn: chunk).get();
        for (final d in snap.docs) {
          if (d.id != excludeUid) results.add(UserModel.fromDoc(d));
        }
      }
    }

    await Future.wait(List.generate(chunks.length < 10 ? chunks.length : 10, (_) => worker()));
    return results;
  }

  @override
  Future<void> setPresence(String uid, bool online) async {
    // Respect privacy: hidden values are simply not published.
    final privacy = ((await _users.doc(uid).get()).data()?['privacy'] as Map<String, dynamic>?) ?? const {};
    final hideLastSeen = privacy['lastSeen'] == 'nobody';
    final hideOnline = privacy['online'] == 'nobody';
    await _presence.doc(uid).set({
      'online': hideOnline ? FieldValue.delete() : online,
      'lastSeen': hideLastSeen ? FieldValue.delete() : FieldValue.serverTimestamp(),
      // Heartbeat: proves the app is really open (see _presenceOf).
      'heartbeatAt': hideOnline && hideLastSeen ? FieldValue.delete() : FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Older app versions kept presence on the public profile — remove it.
    if (online) {
      await _users.doc(uid).set({
        'isOnline': FieldValue.delete(),
        'lastSeen': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<void> updatePrivacy(String uid, {bool? hideLastSeen, bool? hideOnline, bool? readReceipts}) async {
    await _users.doc(uid).set({
      'privacy': {
        if (hideLastSeen != null) 'lastSeen': hideLastSeen ? 'nobody' : 'everyone',
        if (hideOnline != null) 'online': hideOnline ? 'nobody' : 'everyone',
        if (readReceipts != null) 'readReceipts': readReceipts,
      },
    }, SetOptions(merge: true));
    // Re-publish presence so the change applies immediately.
    await setPresence(uid, true);
  }

  CollectionReference<Map<String, dynamic>> _blocked(String uid) => _users.doc(uid).collection('blocked');

  @override
  Stream<Set<String>> watchBlocked(String uid) => _blocked(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  @override
  Future<void> setBlocked(String uid, String other, {required bool blocked}) =>
      blocked
          ? _blocked(uid).doc(other).set({'createdAt': FieldValue.serverTimestamp()})
          : _blocked(uid).doc(other).delete();

  @override
  Future<void> updateTokens(String uid, String token, {required bool add}) => _users.doc(uid).set({
    'fcmTokens': add ? FieldValue.arrayUnion([token]) : FieldValue.arrayRemove([token]),
  }, SetOptions(merge: true));
}
