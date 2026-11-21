import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/call_entity.dart';
import '../models/call_model.dart';

/// Signalling over Firestore:
/// ```
/// calls/{callId}
///   chatId, callerId, callerName, callerPhoto, type(voice|video), isGroup,
///   title, photoUrl, participants[], joined[], declined[],
///   status(ringing|ongoing|ended|missed|declined), createdAt, startedAt, endedAt
/// ```
class CallRemoteDataSource {
  CallRemoteDataSource(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _calls => _db.collection(FirestorePaths.calls);

  Future<CallModel> startCall({
    required String chatId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required List<String> participants,
    required bool isGroup,
    required String title,
    String? photoUrl,
    required CallType type,
  }) async {
    final ref = _calls.doc();
    await ref.set({
      'chatId': chatId,
      'callerId': callerId,
      'callerName': callerName,
      if (callerPhoto != null) 'callerPhoto': callerPhoto,
      'type': type.name,
      'isGroup': isGroup,
      'title': title,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'participants': participants,
      'joined': [callerId],
      'declined': <String>[],
      'status': CallStatus.ringing.name,
      'createdAt': FieldValue.serverTimestamp(),
      'clientCreatedAt': Timestamp.now(),
    });
    return CallModel.fromDoc(await ref.get());
  }

  Stream<CallModel?> watchCall(String id) =>
      _calls.doc(id).snapshots().map((d) => d.exists ? CallModel.fromDoc(d) : null);

  Stream<List<CallModel>> watchIncoming(String uid) => _calls
      .where('participants', arrayContains: uid)
      // "ongoing" too: in a group call others can still join after the first answer.
      .where('status', whereIn: [CallStatus.ringing.name, CallStatus.ongoing.name])
      .snapshots()
      .map((s) => s.docs.map(CallModel.fromDoc).toList());

  Stream<List<CallModel>> watchCallLog(String uid) => _calls
      .where('participants', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(CallModel.fromDoc).toList());

  Future<void> accept(String callId, String uid) => _db.runTransaction((tx) async {
    final ref = _calls.doc(callId);
    final snap = await tx.get(ref);
    final status = snap.data()?['status'];
    if (status != CallStatus.ringing.name && status != CallStatus.ongoing.name) {
      throw StateError('This call has already ended.');
    }
    tx.update(ref, {
      'joined': FieldValue.arrayUnion([uid]),
      'status': CallStatus.ongoing.name,
      if (status == CallStatus.ringing.name) 'startedAt': FieldValue.serverTimestamp(),
    });
  });

  Future<void> decline(String callId, String uid) => _db.runTransaction((tx) async {
    final ref = _calls.doc(callId);
    final snap = await tx.get(ref);
    final data = snap.data();
    if (data == null) return;
    final isGroup = data['isGroup'] == true;
    if (!isGroup) {
      tx.update(ref, {
        'declined': FieldValue.arrayUnion([uid]),
        'status': CallStatus.declined.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    // Group: end the ringing only when every invitee has declined.
    final participants = List<String>.from(data['participants'] as List<dynamic>);
    final declined = {...List<String>.from((data['declined'] as List<dynamic>?) ?? const []), uid};
    final callerId = data['callerId'] as String;
    final everyoneDeclined = participants.where((p) => p != callerId).every(declined.contains);
    tx.update(ref, {
      'declined': FieldValue.arrayUnion([uid]),
      if (everyoneDeclined && data['status'] == CallStatus.ringing.name) ...{
        'status': CallStatus.declined.name,
        'endedAt': FieldValue.serverTimestamp(),
      },
    });
  });

  Future<void> leave(String callId, String uid) => _db.runTransaction((tx) async {
    final ref = _calls.doc(callId);
    final snap = await tx.get(ref);
    final data = snap.data();
    if (data == null) return;
    final status = data['status'] as String?;
    if (status != CallStatus.ringing.name && status != CallStatus.ongoing.name) return;

    final isGroup = data['isGroup'] == true;
    final joined = List<String>.from((data['joined'] as List<dynamic>?) ?? const [])..remove(uid);
    final endNow = !isGroup || joined.isEmpty;
    tx.update(ref, {
      'joined': FieldValue.arrayRemove([uid]),
      if (endNow) ...{
        // Caller hanging up before anyone answered → missed for the others.
        'status': status == CallStatus.ringing.name ? CallStatus.missed.name : CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
      },
    });
  });

  Future<void> markMissed(String callId) => _db.runTransaction((tx) async {
    final ref = _calls.doc(callId);
    final snap = await tx.get(ref);
    if (snap.data()?['status'] != CallStatus.ringing.name) return;
    tx.update(ref, {'status': CallStatus.missed.name, 'endedAt': FieldValue.serverTimestamp()});
  });

  Future<String> fetchRtcToken(String channel, int rtcUid) async {
    final result = await _functions.httpsCallable(Env.agoraTokenFunction).call<dynamic>({
      'channelName': channel,
      'uid': rtcUid,
    });
    // Callable results arrive as Map<Object?, Object?> on mobile.
    final data = result.data as Map<Object?, Object?>;
    return (data['token'] as String?) ?? '';
  }
}
