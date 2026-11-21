import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/usecases/user_usecases.dart';

/// The signed-in user's blocked contacts, kept live for the whole session.
///
/// Blocking is enforced on the server (security rules reject messages and
/// calls between blocked users, and hide presence); this class drives the UI.
class BlockList extends ChangeNotifier {
  BlockList(this._privacy);
  final PrivacySettings _privacy;

  StreamSubscription<Set<String>>? _sub;
  String? _uid;
  Set<String> _blocked = const {};

  Set<String> get blocked => _blocked;
  bool isBlocked(String? uid) => uid != null && _blocked.contains(uid);

  void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _sub = _privacy.blocked(uid).listen((ids) {
      _blocked = ids;
      notifyListeners();
    }, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _blocked = const {};
    notifyListeners();
  }

  Future<String?> block(String other) async {
    final uid = _uid;
    if (uid == null) return 'Not signed in';
    final r = await _privacy.block(uid, other);
    return r.fold((f) => f.message, (_) => null);
  }

  Future<String?> unblock(String other) async {
    final uid = _uid;
    if (uid == null) return 'Not signed in';
    final r = await _privacy.unblock(uid, other);
    return r.fold((f) => f.message, (_) => null);
  }
}
