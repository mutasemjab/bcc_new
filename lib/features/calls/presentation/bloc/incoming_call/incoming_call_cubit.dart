import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/call_entity.dart';
import '../../../domain/usecases/call_usecases.dart';

/// App-wide listener for calls that are ringing for the signed-in user.
/// State is the call currently ringing (or null).
class IncomingCallCubit extends Cubit<CallEntity?> {
  IncomingCallCubit(this._watchIncoming, this._accept, this._decline) : super(null);

  final WatchIncomingCalls _watchIncoming;
  final AcceptCall _accept;
  final DeclineCall _decline;

  StreamSubscription<List<CallEntity>>? _sub;
  String? _uid;

  void start(String uid) {
    if (_uid == uid && _sub != null) return;
    stop();
    _uid = uid;
    _sub = _watchIncoming(uid).listen((calls) {
      if (isClosed) return;
      emit(calls.isEmpty ? null : calls.first);
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    if (!isClosed) emit(null);
  }

  /// Returns null on success, or an error message.
  Future<String?> accept(CallEntity call) async {
    final uid = _uid;
    if (uid == null) return tr('Not signed in');
    final r = await _accept((call.id, uid));
    return r.fold<String?>((f) => f.message, (_) => null);
  }

  Future<void> decline(CallEntity call) async {
    final uid = _uid;
    if (uid == null) return;
    await _decline((call.id, uid));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
