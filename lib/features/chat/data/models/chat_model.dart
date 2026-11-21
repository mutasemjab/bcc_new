import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_x.dart';
import '../../domain/entities/chat_entity.dart';
import 'message_model.dart';

class ChatModel extends ChatEntity {
  const ChatModel({
    required super.id,
    required super.isGroup,
    required super.participants,
    super.name,
    super.photoUrl,
    super.description,
    super.admins,
    super.createdBy,
    super.lastMessage,
    super.updatedAt,
    super.unread,
    super.typing,
    super.pinnedBy,
    super.mutedBy,
    super.invited,
    super.invitedBy,
    super.anonymous,
    super.revealedAt,
    super.pinnedMessages,
    super.inviteCode,
    super.clearedAt,
    super.deletedAt,
  });

  factory ChatModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final last = d['lastMessage'] as Map<String, dynamic>?;
    return ChatModel(
      id: doc.id,
      isGroup: d.boolean('isGroup'),
      participants: d.strList('participants'),
      name: d.strOrNull('name'),
      photoUrl: d.strOrNull('photoUrl'),
      description: d.strOrNull('description'),
      admins: d.strList('admins'),
      createdBy: d.strOrNull('createdBy'),
      lastMessage:
          last == null
              ? null
              : LastMessage(
                id: last.str('id'),
                senderId: last.str('senderId'),
                type: MessageModel.typeFromString(last.str('type')),
                preview: last.str('preview'),
                createdAt: last.date('createdAt'),
              ),
      updatedAt: d.date('updatedAt'),
      unread: d.mapOf<int>('unread', (v) => (v as num?)?.toInt() ?? 0),
      typing: d.mapOf<bool>('typing', (v) => v == true),
      pinnedBy: d.strList('pinnedBy'),
      mutedBy: d.strList('mutedBy'),
      invited: d.strList('invited'),
      invitedBy: d.mapOf<String>('invitedBy', (v) => v.toString()),
      anonymous: d.mapOf<String>('anonymous', (v) => v.toString()),
      revealedAt: {
        for (final e in ((d['revealedAt'] as Map<String, dynamic>?) ?? const {}).entries)
          if (e.value is Timestamp) e.key: (e.value as Timestamp).toDate(),
      },
      pinnedMessages: [
        for (final p in (d['pinnedMessages'] as List<dynamic>? ?? const []))
          if (p is Map<String, dynamic>)
            PinnedMessage(
              messageId: p.str('messageId'),
              senderId: p.str('senderId'),
              type: MessageModel.typeFromString(p.str('type')),
              preview: p.str('preview'),
              pinnedBy: p.str('pinnedBy'),
              pinnedAt: p.date('pinnedAt'),
            ),
      ],
      inviteCode: d.strOrNull('inviteCode'),
      clearedAt: _times(d['clearedAt']),
      deletedAt: _times(d['deletedAt']),
    );
  }

  static Map<String, DateTime> _times(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is Timestamp) '${e.key}': (e.value as Timestamp).toDate(),
    };
  }
}
