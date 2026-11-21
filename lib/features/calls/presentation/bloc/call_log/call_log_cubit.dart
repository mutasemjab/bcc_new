import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/call_entity.dart';
import '../../../domain/usecases/call_usecases.dart';

class CallLogState extends Equatable {
  const CallLogState({this.uid = '', this.calls = const [], this.loading = true, this.missedOnly = false});
  final String uid;
  final List<CallEntity> calls;
  final bool loading;
  final bool missedOnly;

  /// Incoming, never answered by me, and not actively declined by me.
  bool isMissed(CallEntity c) =>
      !c.isOutgoingFor(uid) &&
      !c.declined.contains(uid) &&
      !c.isActive &&
      (c.status == CallStatus.missed || c.startedAt == null);

  List<CallEntity> get visible => missedOnly ? calls.where(isMissed).toList() : calls;

  CallLogState copyWith({String? uid, List<CallEntity>? calls, bool? loading, bool? missedOnly}) => CallLogState(
    uid: uid ?? this.uid,
    calls: calls ?? this.calls,
    loading: loading ?? this.loading,
    missedOnly: missedOnly ?? this.missedOnly,
  );

  @override
  List<Object?> get props => [uid, calls, loading, missedOnly];
}

class CallLogCubit extends Cubit<CallLogState> {
  CallLogCubit(this._watchLog) : super(const CallLogState());
  final WatchCallLog _watchLog;
  StreamSubscription<List<CallEntity>>? _sub;

  void start(String uid) {
    if (state.uid == uid && _sub != null) return;
    _sub?.cancel();
    emit(CallLogState(uid: uid));
    _sub = _watchLog(uid).listen(
      (calls) {
        if (!isClosed) emit(state.copyWith(calls: calls, loading: false));
      },
      onError: (Object _) {
        if (!isClosed) emit(state.copyWith(loading: false));
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    emit(const CallLogState());
  }

  void toggleMissedOnly() => emit(state.copyWith(missedOnly: !state.missedOnly));

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
