import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/user_usecases.dart';

class UserSearchState extends Equatable {
  const UserSearchState({this.query = '', this.results = const [], this.isLoading = false, this.error});
  final String query;
  final List<UserEntity> results;
  final bool isLoading;
  final String? error;

  @override
  List<Object?> get props => [query, results, isLoading, error];
}

/// Debounced global user search (name prefix, email or phone).
class UserSearchCubit extends Cubit<UserSearchState> {
  UserSearchCubit(this._search, this._currentUid) : super(const UserSearchState());

  final SearchUsers _search;
  final String _currentUid;
  Timer? _debounce;
  int _requestId = 0;

  void queryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      emit(UserSearchState(query: query));
      return;
    }
    emit(UserSearchState(query: query, results: state.results, isLoading: true));
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(query));
  }

  Future<void> _run(String query) async {
    final id = ++_requestId;
    final result = await _search(SearchUsersParams(query, _currentUid));
    if (id != _requestId || isClosed) return; // a newer query superseded this one
    result.match(
      (f) => emit(UserSearchState(query: query, error: f.message)),
      (users) => emit(UserSearchState(query: query, results: users)),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
