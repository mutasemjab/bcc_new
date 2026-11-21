import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/firestore_x.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    super.email,
    super.phone,
    super.photoUrl,
    super.about,
    super.isOnline,
    super.lastSeen,
    super.hideLastSeen,
    super.hideOnline,
    super.readReceipts,
  });

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return UserModel(
      id: doc.id,
      name: d.str('name'),
      email: d.strOrNull('email'),
      phone: d.strOrNull('phone'),
      photoUrl: d.strOrNull('photoUrl'),
      about: d.str('about', 'Hey there! I am using BCC Chat.'),
      // Presence now lives in presence/{uid}; these are filled in by the data source.
      isOnline: false,
      lastSeen: null,
      hideLastSeen: (d['privacy'] as Map<String, dynamic>?)?['lastSeen'] == 'nobody',
      hideOnline: (d['privacy'] as Map<String, dynamic>?)?['online'] == 'nobody',
      readReceipts: (d['privacy'] as Map<String, dynamic>?)?['readReceipts'] != false,
    );
  }

  /// Same profile with presence merged in (from presence/{uid}).
  UserModel withLivePresence({required bool online, DateTime? lastSeen}) => UserModel(
    id: id,
    name: name,
    email: email,
    phone: phone,
    photoUrl: photoUrl,
    about: about,
    isOnline: online,
    lastSeen: lastSeen,
    hideLastSeen: hideLastSeen,
    hideOnline: hideOnline,
    readReceipts: readReceipts,
  );

  /// Fields written when a profile is created/updated.
  static Map<String, dynamic> profileFields({
    required String name,
    required String about,
    String? photoUrl,
    String? email,
    String? phone,
  }) => {
    'name': name,
    'nameLower': name.toLowerCase(),
    'about': about,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (email != null && email.isNotEmpty) 'email': email.toLowerCase(),
    if (phone != null && phone.isNotEmpty) 'phone': phone,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
