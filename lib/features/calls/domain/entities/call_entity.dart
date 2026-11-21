import 'package:equatable/equatable.dart';

enum CallType { voice, video }

enum CallStatus { ringing, ongoing, ended, missed, declined }

/// A call session. The Agora channel name is the call id.
class CallEntity extends Equatable {
  const CallEntity({
    required this.id,
    required this.chatId,
    required this.callerId,
    required this.callerName,
    required this.type,
    required this.isGroup,
    required this.title,
    required this.participants,
    required this.status,
    this.callerPhoto,
    this.photoUrl,
    this.joined = const [],
    this.declined = const [],
    this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String chatId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final CallType type;
  final bool isGroup;

  /// Group name, or caller name for 1:1.
  final String title;
  final String? photoUrl;
  final List<String> participants;
  final List<String> joined;
  final List<String> declined;
  final CallStatus status;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isVideo => type == CallType.video;
  bool get isActive => status == CallStatus.ringing || status == CallStatus.ongoing;
  String get channelName => id;

  bool isOutgoingFor(String uid) => callerId == uid;

  Duration? get duration => startedAt != null && endedAt != null ? endedAt!.difference(startedAt!) : null;

  /// The "other side" for 1:1 call-log rows.
  String peerFor(String uid) => isGroup ? chatId : participants.firstWhere((p) => p != uid, orElse: () => uid);

  @override
  List<Object?> get props => [
    id,
    chatId,
    callerId,
    callerName,
    callerPhoto,
    type,
    isGroup,
    title,
    photoUrl,
    participants,
    joined,
    declined,
    status,
    createdAt,
    startedAt,
    endedAt,
  ];
}
