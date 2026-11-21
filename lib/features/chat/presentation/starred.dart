import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/routes.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/entities/message_entity.dart';
import 'conversation_args.dart';

/// A starred ("saved") message, stored privately under my account.
class StarredMessage {
  const StarredMessage({
    required this.key,
    required this.chatId,
    required this.messageId,
    required this.chatTitle,
    required this.senderName,
    required this.preview,
    this.sentAt,
    this.starredAt,
  });

  final String key;
  final String chatId;
  final String messageId;
  final String chatTitle;
  final String senderName;
  final String preview;
  final DateTime? sentAt;
  final DateTime? starredAt;
}

/// Session-wide starred messages (live), like BlockList.
class StarredStore extends ChangeNotifier {
  StarredStore(this._db);
  final FirebaseFirestore _db;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  List<StarredMessage> _items = const [];
  Set<String> _keys = const {};

  List<StarredMessage> get items => _items;
  static String keyOf(String chatId, String messageId) => '${chatId}__$messageId';
  bool isStarred(String chatId, String messageId) => _keys.contains(keyOf(chatId, messageId));

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid).collection('starred');

  void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _sub = _col(uid).orderBy('starredAt', descending: true).snapshots().listen((s) {
      _items = [
        for (final d in s.docs)
          StarredMessage(
            key: d.id,
            chatId: d.data()['chatId'] as String? ?? '',
            messageId: d.data()['messageId'] as String? ?? '',
            chatTitle: d.data()['chatTitle'] as String? ?? '',
            senderName: d.data()['senderName'] as String? ?? '',
            preview: d.data()['preview'] as String? ?? '',
            sentAt: (d.data()['sentAt'] as Timestamp?)?.toDate(),
            starredAt: (d.data()['starredAt'] as Timestamp?)?.toDate(),
          ),
      ];
      _keys = {for (final i in _items) i.key};
      notifyListeners();
    }, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _items = const [];
    _keys = const {};
    notifyListeners();
  }

  Future<void> toggle(MessageEntity m, {required String chatTitle, required String senderName}) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _col(uid).doc(keyOf(m.chatId, m.id));
    if (isStarred(m.chatId, m.id)) {
      await ref.delete();
    } else {
      await ref.set({
        'chatId': m.chatId,
        'messageId': m.id,
        'chatTitle': chatTitle,
        'senderName': senderName,
        'preview': m.preview,
        if (m.createdAt != null) 'sentAt': Timestamp.fromDate(m.createdAt!),
        'starredAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> remove(StarredMessage s) async {
    final uid = _uid;
    if (uid != null) await _col(uid).doc(s.key).delete();
  }
}

/// "Starred messages" — tap to jump to the message in its chat.
class StarredMessagesPage extends StatelessWidget {
  const StarredMessagesPage({super.key, this.chatId});

  /// Only this chat's starred messages (null = all chats).
  final String? chatId;

  @override
  Widget build(BuildContext context) {
    final store = sl<StarredStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Starred messages')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.items.where((s) => chatId == null || s.chatId == chatId).toList();
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.star_outline_rounded,
              title: 'No starred messages',
              message: 'Long-press a message and tap ⭐ Star to save it here.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: context.palette.stroke),
            itemBuilder: (_, i) {
              final s = items[i];
              return Dismissible(
                key: ValueKey(s.key),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: AppColors.danger,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.star_border_rounded, color: Colors.white),
                ),
                onDismissed: (_) => store.remove(s),
                child: ListTile(
                  leading: const Icon(Icons.star_rounded, color: AppColors.warning),
                  title: Text(s.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${s.senderName} • ${s.chatTitle}'),
                  trailing: Text(Formatters.chatListTime(s.sentAt), style: context.text.labelSmall),
                  onTap:
                      () => context.push(
                        AppRoutes.conversation(s.chatId),
                        extra: ConversationArgs(jumpToMessageId: s.messageId),
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
