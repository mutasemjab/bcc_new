import '../domain/entities/message_entity.dart';

/// Optional extras when opening a chat.
class ConversationArgs {
  const ConversationArgs({this.jumpToMessageId, this.replyTo});

  /// Scroll to (and highlight) this message once the chat opens.
  final String? jumpToMessageId;

  /// "Reply privately": start a reply quoting this message from a group.
  final MessageEntity? replyTo;
}
