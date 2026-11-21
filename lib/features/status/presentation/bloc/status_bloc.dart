import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/status_entity.dart';
import '../../domain/usecases/status_usecases.dart';

// ── Events ───────────────────────────────────────────────────────────────

sealed class StatusEvent {
  const StatusEvent();
}

class StatusFeedStarted extends StatusEvent {
  const StatusFeedStarted({required this.me, required this.contacts});
  final String me;
  final Set<String> contacts;
}

class StatusFeedStopped extends StatusEvent {
  const StatusFeedStopped();
}

class TextStatusPosted extends StatusEvent {
  const TextStatusPosted(this.text, this.color);
  final String text;
  final int color;
}

class ImageStatusPosted extends StatusEvent {
  const ImageStatusPosted(this.image, this.caption);
  final File image;
  final String caption;
}

class StatusViewed extends StatusEvent {
  const StatusViewed(this.status);
  final StatusEntity status;
}

class StatusDeleted extends StatusEvent {
  const StatusDeleted(this.status);
  final StatusEntity status;
}

class _FeedUpdated extends StatusEvent {
  const _FeedUpdated(this.groups);
  final List<UserStatuses> groups;
}

// ── State ────────────────────────────────────────────────────────────────

class StatusState extends Equatable {
  const StatusState({this.me = '', this.groups = const [], this.loading = true, this.posting = false, this.message});

  final String me;
  final List<UserStatuses> groups;
  final bool loading;
  final bool posting;
  final String? message;

  UserStatuses? get mine => groups.where((g) => g.userId == me).firstOrNull;
  List<UserStatuses> get others => groups.where((g) => g.userId != me).toList();
  List<UserStatuses> get recent => others.where((g) => !g.allSeenBy(me)).toList();
  List<UserStatuses> get viewed => others.where((g) => g.allSeenBy(me)).toList();

  StatusState copyWith({String? me, List<UserStatuses>? groups, bool? loading, bool? posting, String? message}) =>
      StatusState(
        me: me ?? this.me,
        groups: groups ?? this.groups,
        loading: loading ?? this.loading,
        posting: posting ?? this.posting,
        message: message,
      );

  @override
  List<Object?> get props => [me, groups, loading, posting, message];
}

// ── Bloc ─────────────────────────────────────────────────────────────────

class StatusBloc extends Bloc<StatusEvent, StatusState> {
  StatusBloc({
    required WatchStatusFeed watchFeed,
    required PostTextStatus postText,
    required PostImageStatus postImage,
    required MarkStatusViewed markViewed,
    required DeleteStatus deleteStatus,
  }) : _watchFeed = watchFeed,
       _postText = postText,
       _postImage = postImage,
       _markViewed = markViewed,
       _delete = deleteStatus,
       super(const StatusState()) {
    on<StatusFeedStarted>(_onStarted);
    on<StatusFeedStopped>((e, emit) async {
      await _sub?.cancel();
      _sub = null;
      _contacts = {};
      emit(const StatusState());
    });
    on<_FeedUpdated>((e, emit) => emit(state.copyWith(groups: e.groups, loading: false)));
    on<TextStatusPosted>(_onText);
    on<ImageStatusPosted>(_onImage);
    on<StatusViewed>(_onViewed);
    on<StatusDeleted>((e, emit) async {
      final r = await _delete(e.status);
      r.match((f) => emit(state.copyWith(message: f.message)), (_) {});
    });
  }

  final WatchStatusFeed _watchFeed;
  final PostTextStatus _postText;
  final PostImageStatus _postImage;
  final MarkStatusViewed _markViewed;
  final DeleteStatus _delete;

  StreamSubscription<List<UserStatuses>>? _sub;
  Set<String> _contacts = {};
  final _viewedLocally = <String>{};

  Future<void> _onStarted(StatusFeedStarted e, Emitter<StatusState> emit) async {
    final same = e.me == state.me && e.contacts.length == _contacts.length && e.contacts.containsAll(_contacts);
    if (same && _sub != null) return;
    _contacts = e.contacts;
    await _sub?.cancel();
    emit(state.copyWith(me: e.me, loading: state.groups.isEmpty));
    _sub = _watchFeed((me: e.me, contacts: e.contacts)).listen((g) => add(_FeedUpdated(g)));
  }

  Future<void> _onText(TextStatusPosted e, Emitter<StatusState> emit) async {
    emit(state.copyWith(posting: true));
    final r = await _postText((uid: state.me, text: e.text, color: e.color));
    r.match(
      (f) => emit(state.copyWith(posting: false, message: f.message)),
      (_) => emit(state.copyWith(posting: false, message: 'Status shared')),
    );
  }

  Future<void> _onImage(ImageStatusPosted e, Emitter<StatusState> emit) async {
    emit(state.copyWith(posting: true));
    final r = await _postImage((uid: state.me, image: e.image, caption: e.caption));
    r.match(
      (f) => emit(state.copyWith(posting: false, message: f.message)),
      (_) => emit(state.copyWith(posting: false, message: 'Status shared')),
    );
  }

  Future<void> _onViewed(StatusViewed e, Emitter<StatusState> emit) async {
    final s = e.status;
    if (s.userId == state.me || s.seenBy(state.me) || !_viewedLocally.add(s.id)) return;
    await _markViewed((s.id, state.me));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
