import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:equatable/equatable.dart';

enum MessageType { text, image, video, audio, file, location, sticker, poll, system }

/// Delivery state shown with ticks under outgoing messages.
enum DeliveryStatus { pending, sent, delivered, read }

class ReplyInfo extends Equatable {
  const ReplyInfo({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.preview,
  });

  final String messageId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String preview;

  @override
  List<Object?> get props => [messageId, senderId, senderName, type, preview];
}

class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.text = '',
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.waveform = const [],
    this.latitude,
    this.longitude,
    this.replyTo,
    this.createdAt,
    this.deliveredTo = const [],
    this.readBy = const [],
    this.deletedForEveryone = false,
    this.deletedFor = const [],
    this.reactions = const {},
    this.isPending = false,
    this.isEdited = false,
    this.stickerId,
    this.poll,
    this.pollVotes = const {},
    this.forwardCount = 0,
    this.viewOnce = false,
    this.openedBy = const [],
    this.pendingApproval = false,
    this.rejected = false,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final Duration? duration;
  final List<double> waveform;
  final double? latitude;
  final double? longitude;
  final ReplyInfo? replyTo;
  final DateTime? createdAt;
  final List<String> deliveredTo;
  final List<String> readBy;
  final bool deletedForEveryone;
  final List<String> deletedFor;

  /// uid → emoji
  final Map<String, String> reactions;

  /// True while the write is only in the local Firestore cache.
  final bool isPending;
  final bool isEdited;

  /// Built-in sticker id (see StickerCatalog). Custom stickers use [mediaUrl].
  final String? stickerId;

  final PollData? poll;

  /// uid → selected option ids.
  final Map<String, List<String>> pollVotes;

  /// How many times this content has been forwarded (0 = original).
  final int forwardCount;
  bool get isForwarded => forwardCount > 0;
  bool get isFrequentlyForwarded => forwardCount >= 5;

  /// View-once photo / voice note: each recipient can open it one time.
  final bool viewOnce;
  final List<String> openedBy;
  bool openedByUser(String uid) => openedBy.contains(uid);

  /// Media from an anonymous group member, waiting for an admin to approve it.
  final bool pendingApproval;

  /// An admin rejected this media.
  final bool rejected;

  /// Media types an anonymous member needs approval for.
  static const approvalTypes = {MessageType.image, MessageType.video, MessageType.file};

  /// Number of voters per option id.
  Map<String, int> get pollCounts {
    final counts = <String, int>{};
    for (final ids in pollVotes.values) {
      for (final id in ids) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  bool isMine(String uid) => senderId == uid;
  bool isHiddenFor(String uid) => deletedFor.contains(uid);

  /// Delivery status relative to every other participant of the chat.
  DeliveryStatus statusFor(List<String> participants) {
    if (isPending) return DeliveryStatus.pending;
    final others = participants.where((p) => p != senderId).toList();
    if (others.isEmpty) return DeliveryStatus.sent;
    if (others.every(readBy.contains)) return DeliveryStatus.read;
    if (others.every((o) => deliveredTo.contains(o) || readBy.contains(o))) {
      return DeliveryStatus.delivered;
    }
    return DeliveryStatus.sent;
  }

  /// Short human text used in chat list, replies and notifications.
  String get preview {
    if (deletedForEveryone) return tr('This message was deleted');
    if (viewOnce) return type == MessageType.audio ? tr('① Voice message') : tr('① Photo');
    return switch (type) {
      MessageType.text || MessageType.system => text,
      MessageType.image => text.isNotEmpty ? '📷 $text' : tr('📷 Photo'),
      MessageType.video => text.isNotEmpty ? '🎬 $text' : tr('🎬 Video'),
      MessageType.audio => tr('🎤 Voice message'),
      MessageType.file => '📄 ${fileName ?? 'Document'}',
      MessageType.location => tr('📍 Location'),
      MessageType.sticker => tr('💟 Sticker'),
      MessageType.poll => '📊 ${poll?.question ?? 'Poll'}',
    };
  }

  @override
  List<Object?> get props => [
    id,
    chatId,
    senderId,
    type,
    text,
    mediaUrl,
    fileName,
    fileSize,
    duration,
    waveform,
    latitude,
    longitude,
    replyTo,
    createdAt,
    deliveredTo,
    readBy,
    deletedForEveryone,
    deletedFor,
    reactions,
    isPending,
    isEdited,
    stickerId,
    poll,
    pollVotes,
    forwardCount,
    viewOnce,
    openedBy,
    pendingApproval,
    rejected,
  ];
}

class PollOption extends Equatable {
  const PollOption({required this.id, required this.text});
  final String id;
  final String text;
  @override
  List<Object?> get props => [id, text];
}

class PollData extends Equatable {
  const PollData({required this.question, required this.options, this.allowMultiple = false});
  final String question;
  final List<PollOption> options;
  final bool allowMultiple;

  Map<String, dynamic> toMap() => {
    'question': question,
    'allowMultiple': allowMultiple,
    'options': [
      for (final o in options) {'id': o.id, 'text': o.text},
    ],
  };

  static PollData? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return PollData(
      question: (m['question'] as String?) ?? '',
      allowMultiple: (m['allowMultiple'] as bool?) ?? false,
      options: [
        for (final o in (m['options'] as List<dynamic>? ?? const []))
          PollOption(id: '${(o as Map)['id']}', text: '${o['text'] ?? ''}'),
      ],
    );
  }

  @override
  List<Object?> get props => [question, options, allowMultiple];
}
