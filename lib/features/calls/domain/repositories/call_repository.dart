import '../../../../core/usecase/usecase.dart';
import '../entities/call_entity.dart';

/// Call signalling (Firestore) + RTC token issuance (Cloud Functions).
abstract interface class CallRepository {
  ResultFuture<CallEntity> startCall({
    required String chatId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required List<String> participants,
    required bool isGroup,
    required String title,
    String? photoUrl,
    required CallType type,
  });

  Stream<CallEntity?> watchCall(String callId);
  Stream<List<CallEntity>> watchIncoming(String uid);
  Stream<List<CallEntity>> watchCallLog(String uid);

  ResultFuture<void> accept(String callId, String uid);
  ResultFuture<void> decline(String callId, String uid);

  /// Leaves the call; ends it when nobody else remains (or always for 1:1).
  ResultFuture<void> leave(String callId, String uid);
  ResultFuture<void> markMissed(String callId);

  ResultFuture<String> fetchRtcToken({required String channel, required int rtcUid});
}
