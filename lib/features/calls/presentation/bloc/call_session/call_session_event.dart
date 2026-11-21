part of 'call_session_bloc.dart';

sealed class CallSessionEvent {
  const CallSessionEvent();
}

class CallSessionStarted extends CallSessionEvent {
  const CallSessionStarted({required this.callId, required this.myId, required this.isVideo});
  final String callId;
  final String myId;
  final bool isVideo;
}

class CallMicToggled extends CallSessionEvent {
  const CallMicToggled();
}

class CallCameraToggled extends CallSessionEvent {
  const CallCameraToggled();
}

class CallSpeakerToggled extends CallSessionEvent {
  const CallSpeakerToggled();
}

class CallCameraSwitched extends CallSessionEvent {
  const CallCameraSwitched();
}

class CallHangUpPressed extends CallSessionEvent {
  const CallHangUpPressed();
}

class _CallDocChanged extends CallSessionEvent {
  const _CallDocChanged(this.call);
  final CallEntity? call;
}

class _RtcEventReceived extends CallSessionEvent {
  const _RtcEventReceived(this.event);
  final RtcEvent event;
}

class _Ticked extends CallSessionEvent {
  const _Ticked(this.elapsed);
  final Duration elapsed;
}

class _RingTimedOut extends CallSessionEvent {
  const _RingTimedOut();
}
