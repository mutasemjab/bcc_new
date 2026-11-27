import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../../../core/config/env.dart';
import '../../domain/services/rtc_service.dart';

/// Agora implementation of [RtcService]. One instance per call.
class AgoraRtcService implements RtcService {
  RtcEngine? _engine;
  String? _channel;
  final _events = StreamController<RtcEvent>.broadcast();

  /// Exposed for the video view widgets (rendering is SDK-specific).
  RtcEngine? get engine => _engine;
  String? get channel => _channel;

  @override
  Stream<RtcEvent> get events => _events.stream;

  @override
  Future<void> initialize({required bool video}) async {
    if (Env.agoraAppId.isEmpty) {
      throw StateError(tr('AGORA_APP_ID is missing. Run with --dart-define=AGORA_APP_ID=<your id>.'));
    }
    final engine = createAgoraRtcEngine();
    await engine.initialize(
      RtcEngineContext(appId: Env.agoraAppId, channelProfile: ChannelProfileType.channelProfileCommunication),
    );
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) => _events.add(const RtcJoined()),
        onUserJoined: (connection, remoteUid, elapsed) => _events.add(RtcRemoteJoined(remoteUid)),
        onUserOffline: (connection, remoteUid, reason) => _events.add(RtcRemoteLeft(remoteUid)),
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          if (state == RemoteVideoState.remoteVideoStateStopped) {
            _events.add(RtcRemoteVideoChanged(remoteUid, enabled: false));
          } else if (state == RemoteVideoState.remoteVideoStateDecoding ||
              state == RemoteVideoState.remoteVideoStateStarting) {
            _events.add(RtcRemoteVideoChanged(remoteUid, enabled: true));
          }
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (state == ConnectionStateType.connectionStateFailed) _events.add(const RtcConnectionLost());
        },
        onError: (err, msg) {
          if (err == ErrorCodeType.errTokenExpired || err == ErrorCodeType.errInvalidToken) {
            _events.add(RtcFailure(tr('Call authorisation failed ({0}).', [msg])));
          }
        },
      ),
    );
    await engine.enableAudio();
    if (video) {
      await engine.enableVideo();
      await engine.startPreview();
    }
    _engine = engine;
  }

  @override
  Future<void> join({required String channel, required String token, required int uid, required bool video}) async {
    _channel = channel;
    await _engine?.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        publishCameraTrack: video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
    await _engine?.setEnableSpeakerphone(video);
  }

  @override
  Future<void> leave() async => _engine?.leaveChannel();

  @override
  Future<void> setMicMuted(bool muted) async => _engine?.muteLocalAudioStream(muted);

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    await _engine?.muteLocalVideoStream(!enabled);
    if (enabled) {
      await _engine?.startPreview();
    } else {
      await _engine?.stopPreview();
    }
  }

  @override
  Future<void> switchCamera() async => _engine?.switchCamera();

  @override
  Future<void> setSpeakerOn(bool on) async => _engine?.setEnableSpeakerphone(on);

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.leaveChannel();
      } catch (_) {}
      await engine.release();
    }
    await _events.close();
  }
}
