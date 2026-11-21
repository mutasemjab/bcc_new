import 'package:equatable/equatable.dart';

/// A text message waiting to be sent at [sendAt].
class ScheduledMessage extends Equatable {
  const ScheduledMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.sendAt,
    required this.isGroup,
    required this.participants,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime sendAt;
  final bool isGroup;

  /// Used for direct chats (which may not exist yet when it is sent).
  final List<String> participants;

  bool isDue(DateTime now) => !sendAt.isAfter(now);

  @override
  List<Object?> get props => [id, chatId, senderId, text, sendAt, isGroup, participants];
}
