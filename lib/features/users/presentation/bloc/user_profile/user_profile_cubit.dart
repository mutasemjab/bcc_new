import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/user_usecases.dart';

/// Live view of another user's public profile.
class UserProfileCubit extends Cubit<UserEntity?> {
  UserProfileCubit(WatchUser watchUser, String uid) : super(null) {
    _sub = watchUser(uid).listen((u) {
      if (!isClosed) emit(u);
    });
  }

  late final StreamSubscription<UserEntity?> _sub;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
