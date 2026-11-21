/// Real-time media engine abstraction (implemented with Agora in the data layer).
abstract interface class RtcService {
  Stream<RtcEvent> get events;

  Future<void> initialize({required bool video});
  Future<void> join({required String channel, required String token, required int uid, required bool video});
  Future<void> leave();

  Future<void> setMicMuted(bool muted);
  Future<void> setCameraEnabled(bool enabled);
  Future<void> switchCamera();
  Future<void> setSpeakerOn(bool on);

  Future<void> dispose();
}

sealed class RtcEvent {
  const RtcEvent();
}

class RtcJoined extends RtcEvent {
  const RtcJoined();
}

class RtcRemoteJoined extends RtcEvent {
  const RtcRemoteJoined(this.uid);
  final int uid;
}

class RtcRemoteLeft extends RtcEvent {
  const RtcRemoteLeft(this.uid);
  final int uid;
}

class RtcRemoteVideoChanged extends RtcEvent {
  const RtcRemoteVideoChanged(this.uid, {required this.enabled});
  final int uid;
  final bool enabled;
}

class RtcConnectionLost extends RtcEvent {
  const RtcConnectionLost();
}

class RtcFailure extends RtcEvent {
  const RtcFailure(this.message);
  final String message;
}
