import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_x.dart';
import '../../domain/entities/status_entity.dart';

/// statuses/{id}: userId, type, text, backgroundColor, mediaUrl, createdAt, expiresAt, viewers[]
class StatusModel extends StatusEntity {
  const StatusModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.createdAt,
    required super.expiresAt,
    super.text,
    super.backgroundColor,
    super.mediaUrl,
    super.viewers,
  });

  factory StatusModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final created = d.date('createdAt') ?? d.date('clientCreatedAt') ?? DateTime.now();
    return StatusModel(
      id: doc.id,
      userId: d.str('userId'),
      type: d.str('type') == 'image' ? StatusType.image : StatusType.text,
      text: d.str('text'),
      backgroundColor: d.integer('backgroundColor', 0xFF3A9AD9),
      mediaUrl: d.strOrNull('mediaUrl'),
      createdAt: created,
      expiresAt: d.date('expiresAt') ?? created.add(const Duration(hours: 24)),
      viewers: d.strList('viewers'),
    );
  }
}
