import '../domain/usecases/chat_extras.dart';
import 'bloc/chat_list/chat_list_bloc.dart';

/// "Clear chat daily": for chats where I turned it on, clears them (for me
/// only) once per day — the first time the app sees a new day.
class AutoClearService {
  AutoClearService(this._tools);
  final ChatTools _tools;
  final _done = <String>{};

  void onChats(ChatListState state) {
    if (state.uid.isEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final c in state.chats) {
      if (!c.autoClearsFor(state.uid)) continue;
      final cleared = c.clearedAt[state.uid];
      if (cleared != null && !cleared.isBefore(today)) continue;
      final key = '${c.id}@$today';
      if (!_done.add(key)) continue;
      _tools.clearChat(c.id, state.uid);
    }
  }

  void reset() => _done.clear();
}
