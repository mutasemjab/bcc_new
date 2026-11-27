import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../bloc/call_session/call_session_bloc.dart';
import '../call_launcher.dart';
import '../widgets/call_widgets.dart';
import '../widgets/rtc_video_view.dart';

class CallPage extends StatelessWidget {
  const CallPage({super.key, required this.callId, required this.args});
  final String callId;
  final CallRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionBloc>().state;
    if (session is! SessionAuthenticated) return const Scaffold();
    return BlocProvider(
      create:
          (_) =>
              sl<CallSessionBloc>()
                ..add(CallSessionStarted(callId: callId, myId: session.user.id, isVideo: args.isVideo)),
      child: _CallView(args: args),
    );
  }
}

class _CallView extends StatelessWidget {
  const _CallView({required this.args});
  final CallRouteArgs args;

  String _status(CallSessionState s) => switch (s.phase) {
    CallPhase.idle || CallPhase.connecting => tr('Connecting…'),
    CallPhase.ringing => args.isGroup ? tr('Waiting for others…') : tr('Ringing…'),
    CallPhase.active => Formatters.duration(s.elapsed),
    CallPhase.ended => s.endReason ?? tr('Call ended'),
  };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocConsumer<CallSessionBloc, CallSessionState>(
        listenWhen: (p, c) => p.phase != c.phase || (c.error != null && p.error != c.error),
        listener: (context, state) async {
          if (state.phase == CallPhase.ended) {
            await Future<void>.delayed(const Duration(milliseconds: 1200));
            if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          final bloc = context.read<CallSessionBloc>();
          final showVideo = state.isVideo;
          return PopScope(
            canPop: state.phase == CallPhase.ended,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  if (showVideo)
                    _VideoStage(state: state, rtcBloc: bloc, args: args)
                  else
                    _VoiceStage(state: state, args: args, status: _status(state)),
                  // Top bar: name + status (video mode)
                  if (showVideo)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              args.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(_status(state), style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.paddingOf(context).bottom + 20,
                    child: AnimatedOpacity(
                      opacity: state.phase == CallPhase.ended ? 0.4 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: GlassPanel(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (showVideo)
                              CallControl(
                                icon: Icons.cameraswitch_rounded,
                                onTap: () => bloc.add(const CallCameraSwitched()),
                              )
                            else
                              CallControl(
                                icon: state.speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                                active: state.speakerOn,
                                onTap: () => bloc.add(const CallSpeakerToggled()),
                              ),
                            if (showVideo)
                              CallControl(
                                icon: state.cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                                active: !state.cameraOn,
                                onTap: () => bloc.add(const CallCameraToggled()),
                              ),
                            CallControl(
                              icon: state.micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              active: state.micMuted,
                              onTap: () => bloc.add(const CallMicToggled()),
                            ),
                            CallControl(
                              icon: Icons.call_end_rounded,
                              danger: true,
                              size: 68,
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                bloc.add(const CallHangUpPressed());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VoiceStage extends StatelessWidget {
  const _VoiceStage({required this.state, required this.args, required this.status});
  final CallSessionState state;
  final CallRouteArgs args;
  final String status;

  @override
  Widget build(BuildContext context) {
    final users = context.select((ChatListBloc b) => b.state.users);
    final joinedOthers = (state.call?.joined ?? const <String>[]).where((u) => u != state.myId).toList();
    return CallBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  args.isVideo ? tr('Video call') : tr('Voice call'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            PulsingAvatar(
              name: args.displayName,
              photoUrl: args.displayPhoto,
              isGroup: args.isGroup,
              animate: state.phase != CallPhase.active && state.phase != CallPhase.ended,
            ),
            const SizedBox(height: 12),
            Text(
              args.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                status,
                key: ValueKey(state.phase),
                style: TextStyle(
                  color: state.phase == CallPhase.active ? AppColors.accent : Colors.white70,
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (args.isGroup && joinedOthers.isNotEmpty) ...[
              const SizedBox(height: 28),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (final uid in joinedOthers)
                    Column(
                      children: [
                        AppAvatar(name: users[uid]?.name ?? '?', imageUrl: users[uid]?.photoUrl, size: 54),
                        const SizedBox(height: 4),
                        Text(
                          users[uid]?.name.split(' ').first ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const Spacer(flex: 2),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _VideoStage extends StatefulWidget {
  const _VideoStage({required this.state, required this.rtcBloc, required this.args});
  final CallSessionState state;
  final CallSessionBloc rtcBloc;
  final CallRouteArgs args;

  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  Offset _pip = const Offset(16, 120);

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final rtc = widget.rtcBloc.rtc;
    final remotes = state.remoteUids;
    final users = context.select((ChatListBloc b) => b.state.users);
    final size = MediaQuery.sizeOf(context);

    Widget remoteTile(int uid) {
      final fbUid = state.firebaseUidFor(uid);
      final user = fbUid == null ? null : users[fbUid];
      if (state.remoteVideoOff.contains(uid)) {
        return CallBackdrop(
          child: Center(child: AppAvatar(name: user?.name ?? '?', imageUrl: user?.photoUrl, size: 96)),
        );
      }
      return RtcVideoView.remote(key: ValueKey(uid), rtc: rtc, uid: uid);
    }

    Widget localView() =>
        state.cameraOn
            ? RtcVideoView.local(rtc: rtc)
            : const CallBackdrop(
              child: Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 36)),
            );

    // Nobody joined yet → my camera full screen with the ringing overlay.
    if (remotes.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          localView(),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          Center(
            child: PulsingAvatar(
              name: widget.args.displayName,
              photoUrl: widget.args.displayPhoto,
              isGroup: widget.args.isGroup,
              size: 110,
            ),
          ),
        ],
      );
    }

    final stage =
        remotes.length == 1
            ? remoteTile(remotes.first)
            : GridView.count(
              crossAxisCount: remotes.length <= 4 ? 2 : 3,
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 72, bottom: 140),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.75,
              children: [
                for (final uid in remotes) ClipRRect(borderRadius: BorderRadius.circular(18), child: remoteTile(uid)),
              ],
            );

    const pipW = 112.0, pipH = 160.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        stage,
        Positioned(
          left: _pip.dx,
          top: _pip.dy,
          child: GestureDetector(
            onPanUpdate:
                (d) => setState(() {
                  _pip = Offset(
                    (_pip.dx + d.delta.dx).clamp(8.0, size.width - pipW - 8),
                    (_pip.dy + d.delta.dy).clamp(60.0, size.height - pipH - 140),
                  );
                }),
            onPanEnd:
                (_) => setState(() {
                  // Snap to the nearest side.
                  final left = _pip.dx + pipW / 2 < size.width / 2;
                  _pip = Offset(left ? 16 : size.width - pipW - 16, _pip.dy);
                }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: pipW,
              height: pipH,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
              ),
              child: localView(),
            ),
          ),
        ),
      ],
    );
  }
}
