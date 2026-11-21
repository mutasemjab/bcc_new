part of 'conversation_bloc.dart';

sealed class ConversationEvent extends Equatable {
  const ConversationEvent();
  @override
  List<Object?> get props => [];
}

class ConversationStarted extends ConversationEvent {
  const ConversationStarted({required this.chatId, required this.me});
  final String chatId;
  final UserEntity me;
  @override
  List<Object?> get props => [chatId, me.id];
}

class ConversationLoadMore extends ConversationEvent {
  const ConversationLoadMore();
}

class TextMessageSent extends ConversationEvent {
  const TextMessageSent(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

class MediaMessageSent extends ConversationEvent {
  const MediaMessageSent({
    required this.type,
    required this.file,
    this.caption = '',
    this.fileName,
    this.fileSize,
    this.duration,
    this.waveform = const [],
    this.viewOnce = false,
  });
  final MessageType type;
  final File file;
  final String caption;
  final String? fileName;
  final int? fileSize;
  final Duration? duration;
  final List<double> waveform;

  /// Photo / voice note that each recipient can open only once.
  final bool viewOnce;
  @override
  List<Object?> get props => [type, file.path, caption, fileName, viewOnce];
}

class LocationMessageSent extends ConversationEvent {
  const LocationMessageSent(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  @override
  List<Object?> get props => [latitude, longitude];
}

class ReplyTargetChanged extends ConversationEvent {
  const ReplyTargetChanged(this.message);
  final MessageEntity? message;
  @override
  List<Object?> get props => [message?.id];
}

class EditTargetChanged extends ConversationEvent {
  const EditTargetChanged(this.message);
  final MessageEntity? message;
  @override
  List<Object?> get props => [message?.id];
}

class MessageDeleted extends ConversationEvent {
  const MessageDeleted(this.message, {required this.forEveryone});
  final MessageEntity message;
  final bool forEveryone;
  @override
  List<Object?> get props => [message.id, forEveryone];
}

class MessageReacted extends ConversationEvent {
  const MessageReacted(this.message, this.emoji);
  final MessageEntity message;
  final String emoji;
  @override
  List<Object?> get props => [message.id, emoji];
}

class TypingChanged extends ConversationEvent {
  const TypingChanged(this.isTyping);
  final bool isTyping;
  @override
  List<Object?> get props => [isTyping];
}

class _ChatChanged extends ConversationEvent {
  const _ChatChanged(this.chat);
  final ChatEntity? chat;
  @override
  List<Object?> get props => [chat];
}

class _MessagesChanged extends ConversationEvent {
  const _MessagesChanged(this.messages);
  final List<MessageEntity> messages;
  @override
  List<Object?> get props => [messages];
}

class _UsersChanged extends ConversationEvent {
  const _UsersChanged(this.users);
  final Map<String, UserEntity> users;
  @override
  List<Object?> get props => [users];
}

class _UploadProgressed extends ConversationEvent {
  const _UploadProgressed(this.id, this.progress);
  final String id;
  final double progress;
  @override
  List<Object?> get props => [id, progress];
}

class _UploadEnded extends ConversationEvent {
  const _UploadEnded(this.id, this.error);
  final String id;
  final String? error;
  @override
  List<Object?> get props => [id, error];
}

/// A built-in sticker from the sticker panel.
class StickerSent extends ConversationEvent {
  const StickerSent(this.stickerId);
  final String stickerId;
  @override
  List<Object?> get props => [stickerId];
}

class PollSent extends ConversationEvent {
  const PollSent(this.poll);
  final PollData poll;
  @override
  List<Object?> get props => [poll];
}

class PollVoted extends ConversationEvent {
  const PollVoted(this.message, this.optionIds);
  final MessageEntity message;
  final List<String> optionIds;
  @override
  List<Object?> get props => [message.id, optionIds];
}
