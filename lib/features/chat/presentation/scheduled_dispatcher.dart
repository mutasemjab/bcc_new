import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/error/failures.dart';
import '../domain/entities/scheduled_message.dart';
import '../domain/usecases/chat_extras.dart';

/// Sends the user's scheduled messages when they become due.
///
/// Runs while the app is open (and catches up on overdue messages as soon as
/// it opens). If the `sendScheduledMessages` Cloud Function is deployed, the
/// server also sends them while the app is closed; a transaction guarantees
/// each message goes out exactly once.
class ScheduledDispatcher with WidgetsBindingObserver {
  ScheduledDispatcher(this._tools);
  final ChatTools _tools;

  StreamSubscription<List<ScheduledMessage>>? _sub;
  Timer? _timer;
  List<ScheduledMessage> _pending = const [];
  final _inFlight = <String>{};

  void start(String uid) {
    stop();
    WidgetsBinding.instance.addObserver(this);
    _sub = _tools.scheduled(uid).listen((list) {
      _pending = list;
      _arm();
    }, onError: (_) {});
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _pending = const [];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _arm();
  }

  /// Sends what is due now and sets a timer for the next one.
  void _arm() {
    _timer?.cancel();
    final now = DateTime.now();
    for (final m in _pending.where((m) => m.isDue(now))) {
      if (_inFlight.add(m.id)) {
        _tools
            .sendScheduledNow(m)
            .then((r) {
              // Not allowed any more (blocked, removed from the group…) → drop it.
              if (r.isLeft() && r.getLeft().toNullable() is PermissionFailure) _tools.deleteScheduled(m.senderId, m.id);
            })
            .whenComplete(() => _inFlight.remove(m.id));
      }
    }
    final upcoming = _pending.where((m) => !m.isDue(now)).toList();
    if (upcoming.isEmpty) return;
    final next = upcoming.map((m) => m.sendAt).reduce((a, b) => a.isBefore(b) ? a : b);
    // Re-check at least every minute (clock changes, sleep, etc.).
    final wait = next.difference(now);
    _timer = Timer(wait > const Duration(minutes: 1) ? const Duration(minutes: 1) : wait, _arm);
  }
}
