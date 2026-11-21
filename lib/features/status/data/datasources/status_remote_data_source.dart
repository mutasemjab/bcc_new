import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/data/storage_data_source.dart';
import '../../domain/entities/status_entity.dart';
import '../models/status_model.dart';

class StatusRemoteDataSource {
  StatusRemoteDataSource(this._db, this._storage);
  final FirebaseFirestore _db;
  final StorageDataSource _storage;

  static const lifetime = Duration(hours: 24);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(FirestorePaths.statuses);

  Stream<List<StatusModel>> watch(Set<String> userIds) {
    if (userIds.isEmpty) return Stream.value(const []);
    final ids = userIds.toList();
    final cutoff = Timestamp.fromDate(DateTime.now());
    final streams = <Stream<List<StatusModel>>>[
      for (var i = 0; i < ids.length; i += 30)
        _col
            .where('userId', whereIn: ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30))
            .where('expiresAt', isGreaterThan: cutoff)
            .snapshots()
            .map((s) => s.docs.map(StatusModel.fromDoc).toList()),
    ];
    return Rx.combineLatestList(streams).map((lists) => [for (final l in lists) ...l]);
  }

  Map<String, dynamic> _base(String uid) {
    final now = DateTime.now();
    return {
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'clientCreatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(lifetime)),
      'viewers': <String>[],
    };
  }

  Future<void> postText(String uid, String text, int color) =>
      _col.add({..._base(uid), 'type': 'text', 'text': text, 'backgroundColor': color});

  Future<void> postImage(String uid, File image, String caption) async {
    final ref = _col.doc();
    final url = await _storage.uploadFile(
      file: image,
      path: StoragePaths.status(uid, '${ref.id}.jpg'),
      contentType: 'image/jpeg',
    );
    await ref.set({..._base(uid), 'type': 'image', 'mediaUrl': url, 'text': caption});
  }

  Future<void> markViewed(String id, String uid) => _col.doc(id).update({
    'viewers': FieldValue.arrayUnion([uid]),
  });

  Future<void> delete(StatusEntity s) async {
    await _col.doc(s.id).delete();
    if (s.mediaUrl != null) {
      try {
        await _storage.deleteByUrl(s.mediaUrl!);
      } catch (_) {}
    }
  }
}
