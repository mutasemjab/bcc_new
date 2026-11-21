part of 'call_session_bloc.dart';

enum CallPhase { idle, connecting, ringing, active, ended }

class CallSessionState extends Equatable {
  const CallSessionState({
    this.phase = CallPhase.idle,
    this.call,
    this.myId = '',
    this.myRtcUid = 0,
    this.isVideo = false,
    this.remoteUids = const [],
    this.remoteVideoOff = const {},
    this.micMuted = false,
    this.cameraOn = false,
    this.speakerOn = false,
    this.isFrontCamera = true,
    this.elapsed = Duration.zero,
    this.endReason,
    this.error,
  });

  final CallPhase phase;
  final CallEntity? call;
  final String myId;
  final int myRtcUid;
  final bool isVideo;
  final List<int> remoteUids;
  final Set<int> remoteVideoOff;
  final bool micMuted;
  final bool cameraOn;
  final bool speakerOn;
  final bool isFrontCamera;
  final Duration elapsed;
  final String? endReason;
  final String? error;

  /// Maps an Agora uid back to a participant's Firebase uid.
  String? firebaseUidFor(int rtcUid) =>
      call?.participants.cast<String?>().firstWhere((p) => IdUtils.agoraUid(p!) == rtcUid, orElse: () => null);

  CallSessionState copyWith({
    CallPhase? phase,
    CallEntity? call,
    String? myId,
    int? myRtcUid,
    bool? isVideo,
    List<int>? remoteUids,
    Set<int>? remoteVideoOff,
    bool? micMuted,
    bool? cameraOn,
    bool? speakerOn,
    bool? isFrontCamera,
    Duration? elapsed,
    String? endReason,
    String? error,
  }) => CallSessionState(
    phase: phase ?? this.phase,
    call: call ?? this.call,
    myId: myId ?? this.myId,
    myRtcUid: myRtcUid ?? this.myRtcUid,
    isVideo: isVideo ?? this.isVideo,
    remoteUids: remoteUids ?? this.remoteUids,
    remoteVideoOff: remoteVideoOff ?? this.remoteVideoOff,
    micMuted: micMuted ?? this.micMuted,
    cameraOn: cameraOn ?? this.cameraOn,
    speakerOn: speakerOn ?? this.speakerOn,
    isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    elapsed: elapsed ?? this.elapsed,
    endReason: endReason ?? this.endReason,
    error: error,
  );

  @override
  List<Object?> get props => [
    phase,
    call,
    myId,
    myRtcUid,
    isVideo,
    remoteUids,
    remoteVideoOff,
    micMuted,
    cameraOn,
    speakerOn,
    isFrontCamera,
    elapsed,
    endReason,
    error,
  ];
}
