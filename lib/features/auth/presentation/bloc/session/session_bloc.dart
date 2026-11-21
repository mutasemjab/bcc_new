import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/services/push_service.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../users/domain/entities/user_entity.dart';
import '../../../../users/domain/usecases/user_usecases.dart';
import '../../../domain/usecases/auth_usecases.dart';

part 'session_event.dart';
part 'session_state.dart';

/// App-wide session: who is signed in, whether their profile is complete,
/// presence (online / last seen) and push-token registration.
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({
    required WatchAuthState watchAuthState,
    required WatchUser watchUser,
    required SetPresence setPresence,
    required RegisterPushToken registerPushToken,
    required SignOut signOut,
    required PushService pushService,
  }) : _watchAuthState = watchAuthState,
       _watchUser = watchUser,
       _setPresence = setPresence,
       _registerPushToken = registerPushToken,
       _signOut = signOut,
       _push = pushService,
       super(const SessionUnknown()) {
    on<SessionStarted>(_onStarted);
    on<_AuthUidChanged>(_onUidChanged);
    on<_ProfileChanged>(_onProfileChanged);
    on<SessionForegroundChanged>(_onForegroundChanged);
    on<SessionSignOutRequested>(_onSignOut);
  }

  final WatchAuthState _watchAuthState;
  final WatchUser _watchUser;
  final SetPresence _setPresence;
  final RegisterPushToken _registerPushToken;
  final SignOut _signOut;
  final PushService _push;

  StreamSubscription<String?>? _authSub;
  StreamSubscription<UserEntity?>? _userSub;
  StreamSubscription<String>? _tokenSub;
  String? _uid;

  String? get uid => _uid;

  void _onStarted(SessionStarted e, Emitter<SessionState> emit) {
    _authSub ??= _watchAuthState(const NoParams()).listen((uid) => add(_AuthUidChanged(uid)));
  }

  Future<void> _onUidChanged(_AuthUidChanged e, Emitter<SessionState> emit) async {
    await _userSub?.cancel();
    await _tokenSub?.cancel();
    _uid = e.uid;
    if (e.uid == null) {
      emit(const SessionUnauthenticated());
      return;
    }
    final uid = e.uid!;
    _userSub = _watchUser(uid).listen((u) => add(_ProfileChanged(uid, u)));
    unawaited(_registerToken(uid));
  }

  void _onProfileChanged(_ProfileChanged e, Emitter<SessionState> emit) {
    if (e.uid != _uid) return;
    final user = e.user;
    if (user == null || !user.hasProfile) {
      emit(SessionNeedsProfile(e.uid));
      return;
    }
    final wasAuthenticated = state is SessionAuthenticated;
    emit(SessionAuthenticated(user));
    if (!wasAuthenticated) _setPresence(SetPresenceParams(e.uid, true));
  }

  Future<void> _onForegroundChanged(SessionForegroundChanged e, Emitter<SessionState> emit) async {
    final uid = _uid;
    if (uid == null || state is! SessionAuthenticated) return;
    await _setPresence(SetPresenceParams(uid, e.foreground));
  }

  Future<void> _onSignOut(SessionSignOutRequested e, Emitter<SessionState> emit) async {
    final uid = _uid;
    if (uid != null) await _setPresence(SetPresenceParams(uid, false));
    await _signOut(const NoParams());
  }

  Future<void> _registerToken(String uid) async {
    final token = await _push.requestPermissionAndGetToken();
    if (token != null) await _registerPushToken((uid, token));
    _tokenSub = _push.onTokenRefresh.listen((t) => _registerPushToken((uid, t)));
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    await _userSub?.cancel();
    await _tokenSub?.cancel();
    return super.close();
  }
}
