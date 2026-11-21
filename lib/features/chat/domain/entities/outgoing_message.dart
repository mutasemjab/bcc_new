import 'dart:io';

import 'package:equatable/equatable.dart';

import 'message_entity.dart';

/// Everything needed to send a message. Media is uploaded by the repository.
class OutgoingMessage extends Equatable {
  const OutgoingMessage({
    required this.chatId,
    required this.senderId,
    required this.participants,
    required this.isGroup,
    required this.type,
    this.text = '',
    this.file,
    this.fileName,
    this.fileSize,
    this.duration,
    this.waveform = const [],
    this.latitude,
    this.longitude,
    this.replyTo,
    this.stickerId,
    this.poll,
    this.existingMediaUrl,
    this.forwardCount = 0,
    this.viewOnce = false,
  });

  final String chatId;
  final String senderId;

  /// Needed to bump unread counters and create the chat doc lazily.
  final List<String> participants;
  final bool isGroup;
  final MessageType type;
  final String text;
  final File? file;
  final String? fileName;
  final int? fileSize;
  final Duration? duration;
  final List<double> waveform;
  final double? latitude;
  final double? longitude;
  final ReplyInfo? replyTo;
  final String? stickerId;
  final PollData? poll;

  /// Forwarding re-uses already uploaded media instead of uploading again.
  final String? existingMediaUrl;
  final int forwardCount;
  final bool viewOnce;

  bool get hasMedia => file != null;

  @override
  List<Object?> get props => [
    chatId,
    senderId,
    type,
    text,
    file?.path,
    fileName,
    latitude,
    longitude,
    replyTo,
    stickerId,
    poll,
  ];
}
