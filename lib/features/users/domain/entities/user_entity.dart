import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.about = 'Hey there! I am using BCC Chat.',
    this.isOnline = false,
    this.lastSeen,
    this.hideLastSeen = false,
    this.hideOnline = false,
    this.readReceipts = true,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String about;
  final bool isOnline;
  final DateTime? lastSeen;

  // Privacy (only meaningful for the signed-in user's own profile).
  /// Nobody sees my last seen — and I can't see anyone else's.
  final bool hideLastSeen;

  /// Nobody sees when I'm online — and I can't see others online.
  final bool hideOnline;

  /// Off → I don't send blue ticks in 1:1 chats and don't see them either.
  final bool readReceipts;

  bool get hasProfile => name.trim().isNotEmpty;

  /// What to show under the name when there is no live presence.
  String get handle => phone ?? email ?? '';

  UserEntity copyWith({String? name, String? photoUrl, String? about}) => UserEntity(
    id: id,
    name: name ?? this.name,
    email: email,
    phone: phone,
    photoUrl: photoUrl ?? this.photoUrl,
    about: about ?? this.about,
    isOnline: isOnline,
    lastSeen: lastSeen,
    hideLastSeen: hideLastSeen,
    hideOnline: hideOnline,
    readReceipts: readReceipts,
  );

  /// Same profile with live presence from the presence doc (null = hidden).
  UserEntity withPresence({required bool online, DateTime? lastSeen}) => UserEntity(
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

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    photoUrl,
    about,
    isOnline,
    lastSeen,
    hideLastSeen,
    hideOnline,
    readReceipts,
  ];
}
