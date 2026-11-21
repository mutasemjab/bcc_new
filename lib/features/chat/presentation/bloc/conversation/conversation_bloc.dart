import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/utils/id_utils.dart';
import '../../../../users/domain/entities/user_entity.dart';
import '../../../../users/domain/usecases/user_usecases.dart';
import '../../../domain/entities/chat_entity.dart';
import '../../../domain/entities/message_entity.dart';
import '../../../domain/entities/outgoing_message.dart';
import '../../../domain/usecases/chat_usecases.dart';
import '../../../domain/usecases/message_usecases.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

/// Drives a single open conversation (1:1 or group).
class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required WatchChat watchChat,
    required WatchMessages watchMessages,
    required WatchUsers watchUsers,
    required EnsureDirectChat ensureDirectChat,
    required SendMessage sendMessage,
    required MarkMessagesRead markRead,
    required MarkChatRead markChatRead,
    required SetTyping setTyping,
    required DeleteMessage deleteMessage,
    required EditMessage editMessage,
    required ReactToMessage react,
    required VotePoll votePoll,
  }) : _watchChat = watchChat,
       _watchMessages = watchMessages,
       _watchUsers = watchUsers,
       _ensureDirectChat = ensureDirectChat,
       _sendMessage = sendMessage,
       _markRead = markRead,
       _markChatRead = markChatRead,
       _setTyping = setTyping,
       _deleteMessage = deleteMessage,
       _editMessage = editMessage,
       _react = react,
       _votePoll = votePoll,
       super(const ConversationState()) {
    on<ConversationStarted>(_onStarted);
    on<_ChatChanged>(_onChatChanged);
    on<_MessagesChanged>(_onMessagesChanged);
    on<_UsersChanged>((e, emit) => emit(state.copyWith(users: e.users)));
    on<ConversationLoadMore>(_onLoadMore);
    on<TextMessageSent>(_onTextSent);
    on<MediaMessageSent>(_onMediaSent);
    on<LocationMessageSent>(_onLocationSent);
    on<StickerSent>(_onStickerSent);
    on<PollSent>(_onPollSent);
    on<PollVoted>(_onPollVoted);
    on<ReplyTargetChanged>((e, emit) => emit(state.copyWith(replyingTo: () => e.message, editing: () => null)));
    on<EditTargetChanged>((e, emit) => emit(state.copyWith(editing: () => e.message, replyingTo: () => null)));
    on<MessageDeleted>(_onDeleted);
    on<MessageReacted>(_onReacted);
    on<TypingChanged>(_onTyping);
    on<_UploadProgressed>(_onUploadProgressed);
    on<_UploadEnded>(_onUploadEnded);
  }

  final WatchChat _watchChat;
  final WatchMessages _watchMessages;
  final WatchUsers _watchUsers;
  final EnsureDirectChat _ensureDirectChat;
  final SendMessage _sendMessage;
  final MarkMessagesRead _markRead;
  final MarkChatRead _markChatRead;
  final SetTyping _setTyping;
  final DeleteMessage _deleteMessage;
  final EditMessage _editMessage;
  final ReactToMessage _react;
  final VotePoll _votePoll;

  static const _pageSize = 40;
  static const _uuid = Uuid();

  StreamSubscription<ChatEntity?>? _chatSub;
  StreamSubscription<List<MessageEntity>>? _messagesSub;
  StreamSubscription<Map<String, UserEntity>>? _usersSub;
  Set<String> _watchedUsers = {};
  Timer? _typingTimer;
  bool _typingSent = false;
  final _readRequested = <String>{};

  String get _me => state.me!.id;

  Future<void> _onStarted(ConversationStarted e, Emitter<ConversationState> emit) async {
    emit(state.copyWith(chatId: e.chatId, me: e.me, limit: _pageSize));

    // 1:1 chats are created lazily so the first message can be sent offline-first.
    final peer = IdUtils.peerFromChatId(e.chatId, e.me.id);
    if (peer != null) {
      await _ensureDirectChat((e.me.id, peer));
      _watchUserIds({peer});
    }

    _chatSub = _watchChat(e.chatId).listen((c) => add(_ChatChanged(c)));
    // Messages are subscribed once the chat doc arrives (it carries my "clear chat" time).
    await _markChatRead((e.chatId, e.me.id));
  }

  bool _subscribed = false;
  DateTime? _clearedAt;

  void _subscribeMessages() {
    _subscribed = true;
    _messagesSub?.cancel();
    _messagesSub = _watchMessages((state.chatId, state.limit, null)).listen((m) => add(_MessagesChanged(m)));
  }

  void _watchUserIds(Set<String> ids) {
    if (ids.length == _watchedUsers.length && ids.containsAll(_watchedUsers)) return;
    _watchedUsers = ids;
    _usersSub?.cancel();
    _usersSub = _watchUsers(ids).listen((u) => add(_UsersChanged(u)));
  }

  void _onChatChanged(_ChatChanged e, Emitter<ConversationState> emit) {
    final chat = e.chat;
    if (chat == null) {
      if (!_subscribed) _subscribeMessages();
      return;
    }
    final cleared = chat.clearedAt[_me];
    if (!_subscribed || cleared != _clearedAt) {
      _clearedAt = cleared;
      _subscribeMessages();
    }
    final removed = chat.isGroup && !chat.participants.contains(_me);
    emit(state.copyWith(chat: chat, isMember: !removed));
    _watchUserIds(chat.participants.where((p) => p != _me).toSet());
    if (chat.unreadFor(_me) > 0) _markChatRead((chat.id, _me));
  }

  void _onMessagesChanged(_MessagesChanged e, Emitter<ConversationState> emit) {
    // "Clear chat": hide what was there before; anything newer (or still
    // sending) shows normally.
    final cleared = _clearedAt;
    bool afterClear(MessageEntity m) => cleared == null || m.isPending || (m.createdAt?.isAfter(cleared) ?? true);
    final visible = e.messages.where((m) => !m.isHiddenFor(_me) && afterClear(m)).toList();
    final oldest = e.messages.isEmpty ? null : e.messages.last;
    emit(
      state.copyWith(
        messages: visible,
        status: ConversationStatus.ready,
        // Stop paging once we reach messages from before the clear.
        hasMore: e.messages.length >= state.limit && (oldest == null || afterClear(oldest)),
        isLoadingMore: false,
      ),
    );

    // Blue ticks: everything from others that I have not read yet.
    final toRead =
        visible
            .where((m) => !m.isMine(_me) && !m.readBy.contains(_me) && !m.isPending && m.type != MessageType.system)
            .map((m) => m.id)
            .where(_readRequested.add)
            .toList();
    // With read receipts off, 1:1 chats only get "delivered" (groups always send).
    final sendRead = state.isGroup || (state.me?.readReceipts ?? true);
    if (toRead.isNotEmpty) _markRead((state.chatId, _me, toRead, sendRead));
  }

  void _onLoadMore(ConversationLoadMore e, Emitter<ConversationState> emit) {
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(limit: state.limit + _pageSize, isLoadingMore: true));
    _subscribeMessages();
  }

  OutgoingMessage _outgoing(MessageType type, {String text = '', ReplyInfo? reply}) => OutgoingMessage(
    chatId: state.chatId,
    senderId: _me,
    participants:
        state.chat?.participants ??
        [_me, if (IdUtils.peerFromChatId(state.chatId, _me) != null) IdUtils.peerFromChatId(state.chatId, _me)!],
    isGroup: state.chat?.isGroup ?? false,
    type: type,
    text: text,
    replyTo: reply,
  );

  ReplyInfo? _consumeReply(Emitter<ConversationState> emit) {
    final r = state.replyingTo;
    if (r == null) return null;
    emit(state.copyWith(replyingTo: () => null));
    return ReplyInfo(
      messageId: r.id,
      senderId: r.senderId,
      senderName: r.isMine(_me) ? 'You' : state.nameOf(r.senderId),
      type: r.type,
      preview: r.preview,
    );
  }

  Future<void> _onTextSent(TextMessageSent e, Emitter<ConversationState> emit) async {
    _stopTyping();
    final editing = state.editing;
    if (editing != null) {
      emit(state.copyWith(editing: () => null));
      final r = await _editMessage((state.chatId, editing.id, e.text));
      r.match((f) => emit(state.copyWith(error: f.message)), (_) {});
      return;
    }
    final reply = _consumeReply(emit);
    // Fire-and-forget: Firestore's local cache renders it instantly.
    final r = await _sendMessage(SendMessageParams(_outgoing(MessageType.text, text: e.text, reply: reply)));
    r.match((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onMediaSent(MediaMessageSent e, Emitter<ConversationState> emit) async {
    final reply = _consumeReply(emit);
    final uploadId = _uuid.v4();
    emit(
      state.copyWith(
        uploads: [
          ...state.uploads,
          PendingUpload(id: uploadId, type: e.type, localPath: e.file.path, fileName: e.fileName),
        ],
      ),
    );
    final base = _outgoing(e.type, text: e.caption, reply: reply);
    final message = OutgoingMessage(
      chatId: base.chatId,
      senderId: base.senderId,
      participants: base.participants,
      isGroup: base.isGroup,
      type: e.type,
      text: e.caption,
      replyTo: reply,
      file: e.file,
      fileName: e.fileName,
      fileSize: e.fileSize ?? await e.file.length(),
      duration: e.duration,
      waveform: e.waveform,
      viewOnce: e.viewOnce,
    );
    // Not awaited inside the handler so the user can keep chatting while uploading.
    unawaited(
      _sendMessage(
        SendMessageParams(message, onProgress: (p) => add(_UploadProgressed(uploadId, p))),
      ).then((r) => add(_UploadEnded(uploadId, r.fold<String?>((f) => f.message, (_) => null)))),
    );
  }

  Future<void> _onLocationSent(LocationMessageSent e, Emitter<ConversationState> emit) async {
    final reply = _consumeReply(emit);
    final base = _outgoing(MessageType.location, reply: reply);
    final r = await _sendMessage(
      SendMessageParams(
        OutgoingMessage(
          chatId: base.chatId,
          senderId: base.senderId,
          participants: base.participants,
          isGroup: base.isGroup,
          type: MessageType.location,
          latitude: e.latitude,
          longitude: e.longitude,
          replyTo: reply,
        ),
      ),
    );
    r.match((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onStickerSent(StickerSent e, Emitter<ConversationState> emit) async {
    final reply = _consumeReply(emit);
    final base = _outgoing(MessageType.sticker, reply: reply);
    final r = await _sendMessage(
      SendMessageParams(
        OutgoingMessage(
          chatId: base.chatId,
          senderId: base.senderId,
          participants: base.participants,
          isGroup: base.isGroup,
          type: MessageType.sticker,
          stickerId: e.stickerId,
          replyTo: reply,
        ),
      ),
    );
    r.match((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onPollSent(PollSent e, Emitter<ConversationState> emit) async {
    final base = _outgoing(MessageType.poll);
    final r = await _sendMessage(
      SendMessageParams(
        OutgoingMessage(
          chatId: base.chatId,
          senderId: base.senderId,
          participants: base.participants,
          isGroup: base.isGroup,
          type: MessageType.poll,
          poll: e.poll,
        ),
      ),
    );
    r.match((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onPollVoted(PollVoted e, Emitter<ConversationState> emit) async {
    final r = await _votePoll((chatId: state.chatId, messageId: e.message.id, uid: _me, optionIds: e.optionIds));
    r.match((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  void _onUploadProgressed(_UploadProgressed e, Emitter<ConversationState> emit) {
    emit(state.copyWith(uploads: [for (final u in state.uploads) u.id == e.id ? u.withProgress(e.progress) : u]));
  }

  void _onUploadEnded(_UploadEnded e, Emitter<ConversationState> emit) {
    emit(state.copyWith(uploads: state.uploads.where((u) => u.id != e.id).toList(), error: e.error));
  }

  Future<void> _onDeleted(MessageDeleted e, Emitter<ConversationState> emit) async {
    final r = await _deleteMessage((
      chatId: state.chatId,
      messageId: e.message.id,
      uid: _me,
      forEveryone: e.forEveryone,
    ));
    r.match((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onReacted(MessageReacted e, Emitter<ConversationState> emit) async {
    final current = e.message.reactions[_me];
    final emoji = current == e.emoji ? null : e.emoji; // tap same emoji again → remove
    await _react((chatId: state.chatId, messageId: e.message.id, uid: _me, emoji: emoji));
  }

  void _onTyping(TypingChanged e, Emitter<ConversationState> emit) {
    if (!e.isTyping) {
      _stopTyping();
      return;
    }
    if (!_typingSent) {
      _typingSent = true;
      _setTyping((state.chatId, _me, true));
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (_typingSent && state.chatId.isNotEmpty) {
      _typingSent = false;
      _setTyping((state.chatId, _me, false));
    }
  }

  @override
  Future<void> close() async {
    _stopTyping();
    await _chatSub?.cancel();
    await _messagesSub?.cancel();
    await _usersSub?.cancel();
    return super.close();
  }
}
