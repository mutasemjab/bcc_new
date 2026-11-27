import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/message_entity.dart';

/// Opens a view-once photo or voice note. [onOpened] is called when the
/// viewer closes (marking it earlier could delete the file before it loads).
Future<void> openViewOnce(BuildContext context, MessageEntity m, {required VoidCallback onOpened}) async {
  final url = m.mediaUrl;
  if (url == null) return;
  if (m.type == MessageType.audio) {
    await showModalBottomSheet<void>(context: context, isDismissible: true, builder: (_) => _ViewOnceAudio(url: url));
    onOpened();
  } else {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => _ViewOncePhoto(url: url, caption: m.text)));
    onOpened();
  }
}

class _ViewOncePhoto extends StatelessWidget {
  const _ViewOncePhoto({required this.url, required this.caption});
  final String url;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OneBadge(),
            SizedBox(width: 8),
            Text(tr('View once'), style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                // Plain network image: not written to the disk cache.
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder:
                      (_, child, progress) =>
                          progress == null ? child : const CircularProgressIndicator(color: Colors.white),
                  errorBuilder:
                      (_, __, ___) =>
                          Text(tr('This photo is no longer available'), style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
          ),
          if (caption.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewOnceAudio extends StatefulWidget {
  const _ViewOnceAudio({required this.url});
  final String url;

  @override
  State<_ViewOnceAudio> createState() => _ViewOnceAudioState();
}

class _ViewOnceAudioState extends State<_ViewOnceAudio> {
  final _player = AudioPlayer();
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;
  String? _error;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.positionStream.listen((p) => setState(() => _pos = p)))
      ..add(_player.durationStream.listen((d) => setState(() => _dur = d ?? Duration.zero)))
      ..add(
        _player.playerStateStream.listen((s) {
          setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
        }),
      );
    _player.setUrl(widget.url).then((_) => _player.play()).catchError((Object _) {
      if (mounted) setState(() => _error = tr('This voice message is no longer available'));
      return null;
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _dur.inMilliseconds <= 0 ? 1.0 : _dur.inMilliseconds.toDouble();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _OneBadge(color: AppColors.primary),
                SizedBox(width: 8),
                Text(tr('View once voice message'), style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: TextStyle(color: context.palette.textSecondary))
            else
              Row(
                children: [
                  IconButton.filled(
                    onPressed: () {
                      if (_playing) {
                        _player.pause();
                      } else {
                        if (_pos >= _dur && _dur > Duration.zero) _player.seek(Duration.zero);
                        _player.play();
                      }
                    },
                    icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      value: _pos.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                      max: max,
                      onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  Text(Formatters.duration(_dur - _pos)),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              tr('This voice message disappears once you close it.'),
              style: TextStyle(color: context.palette.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _OneBadge extends StatelessWidget {
  const _OneBadge({this.color = Colors.white});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
    child: Text('1', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
  );
}
