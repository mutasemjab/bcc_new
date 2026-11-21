import '../../../../core/error/error_mapper.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../datasources/call_remote_data_source.dart';

class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl(this._remote);
  final CallRemoteDataSource _remote;

  @override
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
  }) => guard(
    () => _remote.startCall(
      chatId: chatId,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      participants: participants,
      isGroup: isGroup,
      title: title,
      photoUrl: photoUrl,
      type: type,
    ),
  );

  @override
  Stream<CallEntity?> watchCall(String callId) => _remote.watchCall(callId);

  @override
  Stream<List<CallEntity>> watchIncoming(String uid) => _remote.watchIncoming(uid);

  @override
  Stream<List<CallEntity>> watchCallLog(String uid) => _remote.watchCallLog(uid);

  @override
  ResultFuture<void> accept(String callId, String uid) => guard(() => _remote.accept(callId, uid));

  @override
  ResultFuture<void> decline(String callId, String uid) => guard(() => _remote.decline(callId, uid));

  @override
  ResultFuture<void> leave(String callId, String uid) => guard(() => _remote.leave(callId, uid));

  @override
  ResultFuture<void> markMissed(String callId) => guard(() => _remote.markMissed(callId));

  @override
  ResultFuture<String> fetchRtcToken({required String channel, required int rtcUid}) =>
      guard(() => _remote.fetchRtcToken(channel, rtcUid));
}
