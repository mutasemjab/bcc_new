import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_x.dart';
import '../../domain/entities/call_entity.dart';

class CallModel extends CallEntity {
  const CallModel({
    required super.id,
    required super.chatId,
    required super.callerId,
    required super.callerName,
    required super.type,
    required super.isGroup,
    required super.title,
    required super.participants,
    required super.status,
    super.callerPhoto,
    super.photoUrl,
    super.joined,
    super.declined,
    super.createdAt,
    super.startedAt,
    super.endedAt,
  });

  factory CallModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return CallModel(
      id: doc.id,
      chatId: d.str('chatId'),
      callerId: d.str('callerId'),
      callerName: d.str('callerName'),
      callerPhoto: d.strOrNull('callerPhoto'),
      type: d.str('type') == 'video' ? CallType.video : CallType.voice,
      isGroup: d.boolean('isGroup'),
      title: d.str('title'),
      photoUrl: d.strOrNull('photoUrl'),
      participants: d.strList('participants'),
      joined: d.strList('joined'),
      declined: d.strList('declined'),
      status: CallStatus.values.firstWhere((s) => s.name == d.str('status'), orElse: () => CallStatus.ended),
      createdAt: d.date('createdAt') ?? d.date('clientCreatedAt'),
      startedAt: d.date('startedAt'),
      endedAt: d.date('endedAt'),
    );
  }
}
