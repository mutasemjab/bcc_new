import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_x.dart';
import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.type,
    super.text,
    super.mediaUrl,
    super.fileName,
    super.fileSize,
    super.duration,
    super.waveform,
    super.latitude,
    super.longitude,
    super.replyTo,
    super.createdAt,
    super.deliveredTo,
    super.readBy,
    super.deletedForEveryone,
    super.deletedFor,
    super.reactions,
    super.isPending,
    super.isEdited,
    super.stickerId,
    super.poll,
    super.pollVotes,
    super.forwardCount,
    super.viewOnce,
    super.openedBy,
  });

  static MessageType typeFromString(String v) =>
      MessageType.values.firstWhere((t) => t.name == v, orElse: () => MessageType.text);

  factory MessageModel.fromDoc(String chatId, DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final reply = d['replyTo'] as Map<String, dynamic>?;
    final durationMs = d['durationMs'] as num?;
    return MessageModel(
      id: doc.id,
      chatId: chatId,
      senderId: d.str('senderId'),
      type: typeFromString(d.str('type')),
      text: d.str('text'),
      mediaUrl: d.strOrNull('mediaUrl'),
      fileName: d.strOrNull('fileName'),
      fileSize: (d['fileSize'] as num?)?.toInt(),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs.toInt()),
      waveform: (d['waveform'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? const [],
      latitude: d.dbl('latitude'),
      longitude: d.dbl('longitude'),
      replyTo:
          reply == null
              ? null
              : ReplyInfo(
                messageId: reply.str('messageId'),
                senderId: reply.str('senderId'),
                senderName: reply.str('senderName'),
                type: typeFromString(reply.str('type')),
                preview: reply.str('preview'),
              ),
      // Server timestamp is null until the write is acknowledged → fall back
      // to the client clock so ordering and labels stay stable.
      createdAt: d.date('createdAt') ?? d.date('clientCreatedAt'),
      deliveredTo: d.strList('deliveredTo'),
      readBy: d.strList('readBy'),
      deletedForEveryone: d.boolean('deletedForEveryone'),
      deletedFor: d.strList('deletedFor'),
      reactions: d.mapOf<String>('reactions', (v) => v.toString()),
      isPending: doc.metadata.hasPendingWrites,
      isEdited: d.boolean('isEdited'),
      stickerId: d.strOrNull('stickerId'),
      poll: PollData.fromMap(d['poll'] as Map<String, dynamic>?),
      forwardCount: (d['forwardCount'] as num?)?.toInt() ?? 0,
      viewOnce: d.boolean('viewOnce'),
      openedBy: d.strList('openedBy'),
      pollVotes: {
        for (final e in ((d['pollVotes'] as Map<String, dynamic>?) ?? const {}).entries)
          e.key: (e.value as List<dynamic>).map((v) => v.toString()).toList(),
      },
    );
  }

  static Map<String, dynamic> replyToMap(ReplyInfo r) => {
    'messageId': r.messageId,
    'senderId': r.senderId,
    'senderName': r.senderName,
    'type': r.type.name,
    'preview': r.preview,
  };
}
