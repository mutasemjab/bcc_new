import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/call_entity.dart';
import '../bloc/incoming_call/incoming_call_cubit.dart';
import '../call_launcher.dart';
import '../widgets/call_widgets.dart';

/// Full-screen ringing UI with slide-up-style accept / decline.
class IncomingCallPage extends StatefulWidget {
  const IncomingCallPage({super.key, required this.call});
  final CallEntity call;

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  Timer? _vibrate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _vibrate = Timer.periodic(const Duration(milliseconds: 1600), (_) => HapticFeedback.heavyImpact());
  }

  @override
  void dispose() {
    _vibrate?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    _vibrate?.cancel();
    final call = widget.call;
    if (!await CallLauncher.ensurePermissions(context, video: call.isVideo)) {
      setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final error = await context.read<IncomingCallCubit>().accept(call);
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
      context.pop();
      return;
    }
    context.pushReplacement(
      AppRoutes.call(call.id),
      extra: CallRouteArgs(
        isVideo: call.isVideo,
        displayName: call.title,
        displayPhoto: call.photoUrl,
        isGroup: call.isGroup,
      ),
    );
  }

  Future<void> _decline() async {
    if (_busy) return;
    _busy = true;
    await context.read<IncomingCallCubit>().decline(widget.call);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    return BlocListener<IncomingCallCubit, CallEntity?>(
      // Caller hung up / someone else's device answered → close.
      listener: (context, current) {
        if (!_busy && current?.id != call.id && context.canPop()) context.pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: PopScope(
          canPop: false,
          child: Scaffold(
            body: CallBackdrop(
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          color: Colors.white60,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr('BCC Chat {0} call', [call.isVideo ? 'video' : 'voice']),
                          style: const TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ],
                    ),
                    const Spacer(),
                    PulsingAvatar(name: call.title, photoUrl: call.photoUrl, isGroup: call.isGroup),
                    const SizedBox(height: 16),
                    Text(
                      call.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      call.isGroup ? tr('{0} is inviting you…', [call.callerName]) : tr('Incoming call…'),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CallControl(
                            icon: Icons.call_end_rounded,
                            danger: true,
                            size: 74,
                            label: tr('Decline'),
                            onTap: _decline,
                          ),
                          _AcceptButton(isVideo: call.isVideo, busy: _busy, onTap: _accept),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptButton extends StatefulWidget {
  const _AcceptButton({required this.isVideo, required this.busy, required this.onTap});
  final bool isVideo;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Transform.translate(offset: Offset(0, -6 * _c.value), child: child),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child:
                  widget.busy
                      ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                      : Icon(
                        widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('Accept'), style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
