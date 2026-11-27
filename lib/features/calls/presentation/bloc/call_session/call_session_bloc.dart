import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/id_utils.dart';
import '../../../domain/entities/call_entity.dart';
import '../../../domain/services/rtc_service.dart';
import '../../../domain/usecases/call_usecases.dart';

part 'call_session_event.dart';
part 'call_session_state.dart';

/// Orchestrates one call: signalling doc + Agora media + timers.
class CallSessionBloc extends Bloc<CallSessionEvent, CallSessionState> {
  CallSessionBloc({
    required RtcService rtc,
    required WatchCall watchCall,
    required FetchRtcToken fetchToken,
    required LeaveCall leaveCall,
    required MarkCallMissed markMissed,
  }) : _rtc = rtc,
       _watchCall = watchCall,
       _fetchToken = fetchToken,
       _leaveCall = leaveCall,
       _markMissed = markMissed,
       super(const CallSessionState()) {
    on<CallSessionStarted>(_onStarted);
    on<_CallDocChanged>(_onDocChanged);
    on<_RtcEventReceived>(_onRtcEvent);
    on<_Ticked>((e, emit) => emit(state.copyWith(elapsed: e.elapsed)));
    on<CallMicToggled>(_onMic);
    on<CallCameraToggled>(_onCamera);
    on<CallSpeakerToggled>(_onSpeaker);
    on<CallCameraSwitched>((e, emit) async {
      await _rtc.switchCamera();
      emit(state.copyWith(isFrontCamera: !state.isFrontCamera));
    });
    on<CallHangUpPressed>(_onHangUp);
    on<_RingTimedOut>(_onRingTimeout);
  }

  final RtcService _rtc;
  final WatchCall _watchCall;
  final FetchRtcToken _fetchToken;
  final LeaveCall _leaveCall;
  final MarkCallMissed _markMissed;

  /// For video rendering in the presentation layer.
  RtcService get rtc => _rtc;

  static const ringTimeout = Duration(seconds: 45);

  StreamSubscription<CallEntity?>? _docSub;
  StreamSubscription<RtcEvent>? _rtcSub;
  Timer? _ticker;
  Timer? _ringTimer;
  DateTime? _connectedAt;
  bool _tornDown = false;

  Future<void> _onStarted(CallSessionStarted e, Emitter<CallSessionState> emit) async {
    final myRtcUid = IdUtils.agoraUid(e.myId);
    // Show the video layout right away for video calls (not only after joining).
    emit(
      state.copyWith(
        myId: e.myId,
        myRtcUid: myRtcUid,
        phase: CallPhase.connecting,
        isVideo: e.isVideo,
        cameraOn: e.isVideo,
      ),
    );

    _docSub = _watchCall(e.callId).listen((c) => add(_CallDocChanged(c)));
    _rtcSub = _rtc.events.listen((ev) => add(_RtcEventReceived(ev)));

    // Token from the server (Agora App Certificate on). If the server function
    // isn't available, try without a token — this works when the Agora project
    // is in "testing mode" (App ID only, no certificate).
    final tokenResult = await _fetchToken((e.callId, myRtcUid));
    final token = tokenResult.fold<String>((_) => '', (t) => t);
    try {
      await _rtc.initialize(video: e.isVideo);
      await _rtc.join(channel: e.callId, token: token, uid: myRtcUid, video: e.isVideo);
      emit(state.copyWith(isVideo: e.isVideo, cameraOn: e.isVideo, speakerOn: e.isVideo));
      // Make sure my own camera preview is running for video calls.
      if (e.isVideo) await _rtc.setCameraEnabled(true);
    } catch (err) {
      // Leave the signalling doc too, so the other side stops ringing.
      await _leaveCall((e.callId, e.myId));
      await _endLocally(emit, tr('Could not connect the call.'));
      return;
    }
    _ringTimer = Timer(ringTimeout, () => add(const _RingTimedOut()));
  }

  Future<void> _onDocChanged(_CallDocChanged e, Emitter<CallSessionState> emit) async {
    final call = e.call;
    if (call == null) return;
    emit(state.copyWith(call: call));
    if (!call.isActive) {
      final reason = switch (call.status) {
        CallStatus.declined => tr('Call declined'),
        CallStatus.missed => tr('No answer'),
        _ => tr('Call ended'),
      };
      await _endLocally(emit, reason);
      return;
    }
    // Group: everyone else left after the call started → end for me too.
    if (call.isGroup && state.phase == CallPhase.active && call.joined.where((u) => u != state.myId).isEmpty) {
      await _hangUp(emit, tr('Call ended'));
    }
  }

  void _onRtcEvent(_RtcEventReceived e, Emitter<CallSessionState> emit) {
    switch (e.event) {
      case RtcJoined():
        if (state.phase == CallPhase.connecting) emit(state.copyWith(phase: CallPhase.ringing));
      case RtcRemoteJoined(:final uid):
        _ringTimer?.cancel();
        if (_connectedAt == null) {
          _connectedAt = DateTime.now();
          _ticker = Timer.periodic(
            const Duration(seconds: 1),
            (_) => add(_Ticked(DateTime.now().difference(_connectedAt ?? DateTime.now()))),
          );
        }
        emit(state.copyWith(phase: CallPhase.active, remoteUids: {...state.remoteUids, uid}.toList()));
      case RtcRemoteLeft(:final uid):
        final remaining = state.remoteUids.where((u) => u != uid).toList();
        emit(state.copyWith(remoteUids: remaining, remoteVideoOff: {...state.remoteVideoOff}..remove(uid)));
        if (remaining.isEmpty && !(state.call?.isGroup ?? false)) add(const CallHangUpPressed());
      case RtcRemoteVideoChanged(:final uid, :final enabled):
        final off = {...state.remoteVideoOff};
        enabled ? off.remove(uid) : off.add(uid);
        emit(state.copyWith(remoteVideoOff: off));
      case RtcConnectionLost():
        add(const CallHangUpPressed());
      case RtcFailure(:final message):
        // e.g. invalid token (App Certificate on, token server not deployed).
        emit(state.copyWith(error: message));
        add(const CallHangUpPressed());
    }
  }

  Future<void> _onMic(CallMicToggled e, Emitter<CallSessionState> emit) async {
    final muted = !state.micMuted;
    await _rtc.setMicMuted(muted);
    emit(state.copyWith(micMuted: muted));
  }

  Future<void> _onCamera(CallCameraToggled e, Emitter<CallSessionState> emit) async {
    final on = !state.cameraOn;
    await _rtc.setCameraEnabled(on);
    emit(state.copyWith(cameraOn: on));
  }

  Future<void> _onSpeaker(CallSpeakerToggled e, Emitter<CallSessionState> emit) async {
    final on = !state.speakerOn;
    await _rtc.setSpeakerOn(on);
    emit(state.copyWith(speakerOn: on));
  }

  Future<void> _onHangUp(CallHangUpPressed e, Emitter<CallSessionState> emit) => _hangUp(emit, tr('Call ended'));

  Future<void> _onRingTimeout(_RingTimedOut e, Emitter<CallSessionState> emit) async {
    if (state.phase == CallPhase.active || state.call == null) return;
    final call = state.call;
    if (call != null) await _markMissed(call.id);
    await _endLocally(emit, tr('No answer'));
  }

  Future<void> _hangUp(Emitter<CallSessionState> emit, String reason) async {
    final call = state.call;
    if (call != null && state.myId.isNotEmpty) await _leaveCall((call.id, state.myId));
    await _endLocally(emit, reason);
  }

  Future<void> _endLocally(Emitter<CallSessionState> emit, String reason) async {
    if (_tornDown) return;
    _tornDown = true;
    _ticker?.cancel();
    _ringTimer?.cancel();
    emit(state.copyWith(phase: CallPhase.ended, endReason: reason));
    await _rtc.leave().catchError((_) {});
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    _ringTimer?.cancel();
    await _docSub?.cancel();
    await _rtcSub?.cancel();
    // Safety net: app closed mid-call → leave the signalling doc too.
    if (!_tornDown && state.call != null && state.myId.isNotEmpty) {
      await _leaveCall((state.call!.id, state.myId));
    }
    await _rtc.dispose();
    return super.close();
  }
}
