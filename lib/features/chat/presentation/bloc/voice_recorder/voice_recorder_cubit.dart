import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecording {
  const VoiceRecording(this.file, this.duration, this.waveform);
  final File file;
  final Duration duration;
  final List<double> waveform;
}

class VoiceRecorderState extends Equatable {
  const VoiceRecorderState({
    this.isRecording = false,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.permissionDenied = false,
  });

  final bool isRecording;
  final Duration elapsed;

  /// Normalised 0..1 amplitudes captured while recording (live waveform).
  final List<double> levels;
  final bool permissionDenied;

  @override
  List<Object?> get props => [isRecording, elapsed, levels.length, permissionDenied];
}

/// Records voice notes and samples amplitude to draw a real waveform.
class VoiceRecorderCubit extends Cubit<VoiceRecorderState> {
  VoiceRecorderCubit() : super(const VoiceRecorderState());

  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _ticker;
  DateTime? _startedAt;
  final _levels = <double>[];

  static const maxDuration = Duration(minutes: 15);

  Future<void> start() async {
    if (state.isRecording) return;
    if (!await _recorder.hasPermission()) {
      emit(const VoiceRecorderState(permissionDenied: true));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = tr('{0}/voice_{1}.m4a', [dir.path, DateTime.now().millisecondsSinceEpoch]);
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
      path: path,
    );
    _levels.clear();
    _startedAt = DateTime.now();
    emit(const VoiceRecorderState(isRecording: true));

    // ~15 samples / second, each one pushed to the UI straight away so the
    // waveform scrolls smoothly (WhatsApp-like).
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 65)).listen((a) {
      _levels.add(_normalise(a.current));
      if (isClosed || _startedAt == null) return;
      emit(
        VoiceRecorderState(
          isRecording: true,
          elapsed: DateTime.now().difference(_startedAt!),
          levels: _levels.length > 60 ? _levels.sublist(_levels.length - 60) : List.of(_levels),
        ),
      );
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final elapsed = DateTime.now().difference(_startedAt!);
      if (elapsed >= maxDuration) stop();
    });
  }

  /// Finishes and returns the recording (null if too short / not recording).
  Future<VoiceRecording?> stop() async {
    if (!state.isRecording) return null;
    final elapsed = DateTime.now().difference(_startedAt ?? DateTime.now());
    await _cleanupTimers();
    final path = await _recorder.stop();
    emit(const VoiceRecorderState());
    if (path == null || elapsed < const Duration(milliseconds: 800)) return null;
    return VoiceRecording(File(path), elapsed, _downsample(_levels, 48));
  }

  Future<void> cancel() async {
    if (!state.isRecording) return;
    await _cleanupTimers();
    await _recorder.cancel();
    emit(const VoiceRecorderState());
  }

  Future<void> _cleanupTimers() async {
    _ticker?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
  }

  /// dBFS → 0..1 with more contrast: quiet room stays low, speech jumps up.
  static double _normalise(double db) {
    final linear = ((db + 45) / 45).clamp(0.0, 1.0);
    return (linear * linear * 1.15).clamp(0.06, 1.0).toDouble();
  }

  /// Compresses the captured samples into [buckets] bars for storage.
  static List<double> _downsample(List<double> source, int buckets) {
    if (source.isEmpty) return List.filled(buckets, 0.1);
    if (source.length <= buckets) return source.map((v) => double.parse(v.toStringAsFixed(2))).toList();
    final size = source.length / buckets;
    return List.generate(buckets, (i) {
      final start = (i * size).floor();
      final end = ((i + 1) * size).floor().clamp(start + 1, source.length);
      final slice = source.sublist(start, end);
      final peak = slice.reduce((a, b) => a > b ? a : b);
      return double.parse(peak.toStringAsFixed(2));
    });
  }

  @override
  Future<void> close() async {
    await _cleanupTimers();
    await _recorder.dispose();
    return super.close();
  }
}
