import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/call_entity.dart';
import '../repositories/call_repository.dart';

class StartCallParams {
  const StartCallParams({
    required this.chatId,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.participants,
    required this.isGroup,
    required this.title,
    this.photoUrl,
    required this.type,
  });
  final String chatId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final List<String> participants;
  final bool isGroup;
  final String title;
  final String? photoUrl;
  final CallType type;
}

class StartCall extends UseCase<CallEntity, StartCallParams> {
  const StartCall(this._repo);
  final CallRepository _repo;

  /// Agora supports up to 17 broadcasters per channel on the default plan.
  static const maxParticipants = 17;

  @override
  ResultFuture<CallEntity> call(StartCallParams p) async {
    if (p.participants.where((id) => id != p.callerId).isEmpty) {
      return const Left(ValidationFailure('There is nobody to call.'));
    }
    if (p.participants.length > maxParticipants) {
      return const Left(ValidationFailure('Group calls support up to $maxParticipants people.'));
    }
    return _repo.startCall(
      chatId: p.chatId,
      callerId: p.callerId,
      callerName: p.callerName,
      callerPhoto: p.callerPhoto,
      participants: p.participants,
      isGroup: p.isGroup,
      title: p.title,
      photoUrl: p.photoUrl,
      type: p.type,
    );
  }
}

class WatchCall extends StreamUseCase<CallEntity?, String> {
  const WatchCall(this._repo);
  final CallRepository _repo;
  @override
  Stream<CallEntity?> call(String id) => _repo.watchCall(id);
}

/// Calls ringing for me that I have not answered or declined yet.
/// 1:1 calls ring only while "ringing"; group calls keep ringing for the
/// rest of the members after someone answers, within the ring window.
class WatchIncomingCalls extends StreamUseCase<List<CallEntity>, String> {
  const WatchIncomingCalls(this._repo);
  final CallRepository _repo;

  static const ringWindow = Duration(seconds: 45);

  @override
  Stream<List<CallEntity>> call(String uid) => _repo
      .watchIncoming(uid)
      .map(
        (calls) =>
            calls.where((c) {
              if (c.callerId == uid || c.declined.contains(uid) || c.joined.contains(uid)) return false;
              if (!c.isGroup && c.status != CallStatus.ringing) return false;
              final created = c.createdAt;
              return created != null && DateTime.now().difference(created) < ringWindow;
            }).toList(),
      );
}

class WatchCallLog extends StreamUseCase<List<CallEntity>, String> {
  const WatchCallLog(this._repo);
  final CallRepository _repo;
  @override
  Stream<List<CallEntity>> call(String uid) => _repo.watchCallLog(uid);
}

class AcceptCall extends UseCase<void, (String callId, String uid)> {
  const AcceptCall(this._repo);
  final CallRepository _repo;
  @override
  ResultFuture<void> call((String, String) p) => _repo.accept(p.$1, p.$2);
}

class DeclineCall extends UseCase<void, (String callId, String uid)> {
  const DeclineCall(this._repo);
  final CallRepository _repo;
  @override
  ResultFuture<void> call((String, String) p) => _repo.decline(p.$1, p.$2);
}

class LeaveCall extends UseCase<void, (String callId, String uid)> {
  const LeaveCall(this._repo);
  final CallRepository _repo;
  @override
  ResultFuture<void> call((String, String) p) => _repo.leave(p.$1, p.$2);
}

class MarkCallMissed extends UseCase<void, String> {
  const MarkCallMissed(this._repo);
  final CallRepository _repo;
  @override
  ResultFuture<void> call(String id) => _repo.markMissed(id);
}

class FetchRtcToken extends UseCase<String, (String channel, int rtcUid)> {
  const FetchRtcToken(this._repo);
  final CallRepository _repo;
  @override
  ResultFuture<String> call((String, int) p) => _repo.fetchRtcToken(channel: p.$1, rtcUid: p.$2);
}
