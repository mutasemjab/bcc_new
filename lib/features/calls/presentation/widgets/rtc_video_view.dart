import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../data/services/agora_rtc_service.dart';
import '../../domain/services/rtc_service.dart';

/// Renders a local or remote video track.
///
/// Rendering is inherently SDK-specific, so this widget is the single place
/// in presentation that knows about Agora types. The controller is cached so
/// rebuilds (timer ticks, toggles) never re-create the native view.
class RtcVideoView extends StatefulWidget {
  const RtcVideoView.local({super.key, required this.rtc}) : remoteUid = null;
  const RtcVideoView.remote({super.key, required this.rtc, required int uid}) : remoteUid = uid;

  final RtcService rtc;
  final int? remoteUid;

  @override
  State<RtcVideoView> createState() => _RtcVideoViewState();
}

class _RtcVideoViewState extends State<RtcVideoView> {
  VideoViewController? _controller;

  VideoViewController? _build() {
    final rtc = widget.rtc;
    if (rtc is! AgoraRtcService) return null;
    final engine = rtc.engine;
    if (engine == null) return null;
    final uid = widget.remoteUid;
    if (uid == null) {
      return VideoViewController(rtcEngine: engine, canvas: const VideoCanvas(uid: 0));
    }
    return VideoViewController.remote(
      rtcEngine: engine,
      canvas: VideoCanvas(uid: uid),
      connection: RtcConnection(channelId: rtc.channel),
    );
  }

  @override
  void didUpdateWidget(RtcVideoView old) {
    super.didUpdateWidget(old);
    if (old.remoteUid != widget.remoteUid || old.rtc != widget.rtc) _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    _controller ??= _build();
    final c = _controller;
    if (c == null) return const ColoredBox(color: Colors.black);
    return AgoraVideoView(controller: c);
  }
}
