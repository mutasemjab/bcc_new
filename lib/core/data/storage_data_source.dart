import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Thin wrapper over Firebase Storage shared by every feature.
abstract interface class StorageDataSource {
  Future<String> uploadFile({
    required File file,
    required String path,
    String? contentType,
    void Function(double progress)? onProgress,
  });

  Future<void> deleteByUrl(String url);
}

class FirebaseStorageDataSource implements StorageDataSource {
  FirebaseStorageDataSource(this._storage);
  final FirebaseStorage _storage;

  @override
  Future<String> uploadFile({
    required File file,
    required String path,
    String? contentType,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref(path);
    final task = ref.putFile(file, SettableMetadata(contentType: contentType));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
      return await ref.getDownloadURL();
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
