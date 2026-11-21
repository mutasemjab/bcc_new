import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../domain/entities/message_entity.dart';

/// Only one voice note plays at a time across the app.
class _ActivePlayer {
  static AudioPlayer? current;
}

/// Voice-note bubble: play/pause, scrubbable waveform, speed toggle.
class AudioContent extends StatefulWidget {
  const AudioContent({super.key, required this.message, required this.isMine, this.avatar});
  final MessageEntity message;
  final bool isMine;
  final Widget? avatar;

  @override
  State<AudioContent> createState() => _AudioContentState();
}

class _AudioContentState extends State<AudioContent> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  bool _loaded = false;
  bool _loading = false;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _player
          ..pause()
          ..seek(Duration.zero);
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      final url = widget.message.mediaUrl;
      if (url == null) return;
      setState(() => _loading = true);
      try {
        await _player.setUrl(url);
        _loaded = true;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    if (_ActivePlayer.current != null && _ActivePlayer.current != _player) {
      await _ActivePlayer.current!.pause();
    }
    _ActivePlayer.current = _player;
    unawaited(_player.play());
  }

  void _cycleSpeed() {
    setState(() => _speed = _speed == 1 ? 1.5 : (_speed == 1.5 ? 2 : 1));
    _player.setSpeed(_speed);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    if (_ActivePlayer.current == _player) _ActivePlayer.current = null;
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? Colors.white : context.palette.incomingText;
    final muted =
        widget.isMine ? Colors.white.withValues(alpha: 0.45) : context.palette.textSecondary.withValues(alpha: 0.45);
    final total = widget.message.duration ?? _player.duration ?? Duration.zero;
    final waveform = widget.message.waveform.isEmpty ? List.filled(40, 0.3) : widget.message.waveform;

    return SizedBox(
      width: 250,
      child: Row(
        children: [
          if (widget.avatar != null) ...[widget.avatar!, const SizedBox(width: 8)],
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMine ? Colors.white.withValues(alpha: 0.2) : AppColors.primary,
              ),
              child:
                  _loading
                      ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                      : Icon(
                        _player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final progress =
                    total.inMilliseconds == 0 ? 0.0 : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder:
                          (context, c) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown:
                                _loaded
                                    ? (d) => _player.seek(total * (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0))
                                    : null,
                            onHorizontalDragUpdate:
                                _loaded
                                    ? (d) => _player.seek(total * (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0))
                                    : null,
                            child: SizedBox(
                              height: 30,
                              child: CustomPaint(
                                size: Size(c.maxWidth, 30),
                                painter: WaveformPainter(
                                  samples: waveform,
                                  progress: progress,
                                  activeColor: fg,
                                  inactiveColor: muted,
                                ),
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          Formatters.duration(_player.playing || pos > Duration.zero ? pos : total),
                          style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11.5),
                        ),
                        const Spacer(),
                        if (_loaded)
                          GestureDetector(
                            onTap: _cycleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: fg.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}×',
                                style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded bars, filled up to [progress].
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    const barWidth = 3.0;
    final count = (size.width / (barWidth + 2)).floor().clamp(1, 200);
    final gap = (size.width - count * barWidth) / (count - 1).clamp(1, 200);
    final paint =
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = barWidth;
    for (var i = 0; i < count; i++) {
      final sample = samples[(i * samples.length / count).floor().clamp(0, samples.length - 1)];
      final h = (sample.clamp(0.08, 1.0)) * size.height;
      final x = i * (barWidth + gap) + barWidth / 2;
      paint.color = (i / count) <= progress ? activeColor : inactiveColor;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.progress != progress || old.samples != samples || old.activeColor != activeColor;
}
