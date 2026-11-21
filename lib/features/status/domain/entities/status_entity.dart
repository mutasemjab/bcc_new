import 'package:equatable/equatable.dart';

enum StatusType { text, image }

/// A 24-hour story.
class StatusEntity extends Equatable {
  const StatusEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
    this.text = '',
    this.backgroundColor = 0xFF3A9AD9,
    this.mediaUrl,
    this.viewers = const [],
  });

  final String id;
  final String userId;
  final StatusType type;

  /// Text story body, or the caption of an image story.
  final String text;
  final int backgroundColor;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;

  bool seenBy(String uid) => viewers.contains(uid);

  @override
  List<Object?> get props => [id, userId, type, text, backgroundColor, mediaUrl, createdAt, expiresAt, viewers];
}

/// All active statuses of one person, oldest first.
class UserStatuses extends Equatable {
  const UserStatuses({required this.userId, required this.statuses});
  final String userId;
  final List<StatusEntity> statuses;

  DateTime get latest => statuses.last.createdAt;
  int seenCount(String uid) => statuses.where((s) => s.seenBy(uid)).length;
  bool allSeenBy(String uid) => statuses.every((s) => s.seenBy(uid));

  /// Index of the first unseen story, so the viewer resumes where you left off.
  int firstUnseenIndex(String uid) {
    final i = statuses.indexWhere((s) => !s.seenBy(uid));
    return i < 0 ? 0 : i;
  }

  @override
  List<Object?> get props => [userId, statuses];
}
