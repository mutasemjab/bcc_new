import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/chat_notifications.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/chat_wallpaper.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../calls/domain/entities/call_entity.dart';
import '../../../calls/presentation/call_launcher.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/scheduled_message.dart';
import '../../domain/usecases/chat_extras.dart';
import '../../../users/presentation/block_list.dart';
import '../chat_actions.dart';
import '../bloc/conversation/conversation_bloc.dart';
import '../bloc/voice_recorder/voice_recorder_cubit.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../appointments/appointments.dart';
import '../chat_export.dart';
import '../conversation_args.dart';
import '../starred.dart';
import 'photo_preview_page.dart';
import '../widgets/composer.dart';
import '../widgets/join_identity_sheet.dart';
import '../widgets/conversation_banners.dart';
import '../widgets/create_poll_sheet.dart';
import '../widgets/forward_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/sheets.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/upload_bubble.dart';
import '../widgets/view_once_viewer.dart';

class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key, required this.chatId, this.args});
  final String chatId;
  final ConversationArgs? args;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionBloc>().state;
    if (session is! SessionAuthenticated) return const Scaffold();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ConversationBloc>()..add(ConversationStarted(chatId: chatId, me: session.user))),
        BlocProvider(create: (_) => VoiceRecorderCubit()),
      ],
      child: _ConversationView(chatId: chatId, args: args),
    );
  }
}

class _ConversationView extends StatefulWidget {
  const _ConversationView({required this.chatId, this.args});
  final String chatId;
  final ConversationArgs? args;
  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  final _scroll = ScrollController();
  bool _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    // No notifications for the chat on screen; clear the ones already shown.
    ChatNotifications.openChatId = widget.chatId;
    ChatNotifications.clearChat(widget.chatId);
    // Opened from "Starred messages" → jump to it; from "Reply privately" →
    // start a reply quoting the group message.
    final args = widget.args;
    if (args != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _bloc.stream
            .firstWhere((s) => s.status == ConversationStatus.ready)
            .timeout(const Duration(seconds: 10), onTimeout: () => _bloc.state);
        if (!mounted) return;
        if (args.replyTo != null) _bloc.add(ReplyTargetChanged(args.replyTo));
        if (args.jumpToMessageId != null) await _jumpTo(args.jumpToMessageId!);
      });
    }
    _scroll.addListener(() {
      final show = _scroll.offset > 400;
      if (show != _showScrollDown) setState(() => _showScrollDown = show);
      if (_scroll.position.extentAfter < 300) context.read<ConversationBloc>().add(const ConversationLoadMore());
    });
  }

  @override
  void dispose() {
    if (ChatNotifications.openChatId == widget.chatId) ChatNotifications.openChatId = null;
    _scroll.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  ConversationBloc get _bloc => context.read<ConversationBloc>();

  // ── Jump to a message (pinned banner, quoted replies) ──

  final _messageKeys = <String, GlobalKey>{};
  String? _highlightId;
  Timer? _highlightTimer;

  GlobalKey _keyFor(String id) => _messageKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _jumpTo(String messageId) async {
    // 1) Page older history in until the message is loaded.
    for (var i = 0; i < 25 && !_bloc.state.messages.any((m) => m.id == messageId); i++) {
      if (!_bloc.state.hasMore) break;
      final before = _bloc.state.messages.length;
      _bloc.add(const ConversationLoadMore());
      await _bloc.stream
          .firstWhere((s) => s.messages.length > before || !s.hasMore)
          .timeout(const Duration(seconds: 8), onTimeout: () => _bloc.state);
    }
    if (!mounted) return;
    if (!_bloc.state.messages.any((m) => m.id == messageId)) {
      AppFeedback.info(context, tr('That message is no longer available'));
      return;
    }
    // 2) Scroll until its bubble is built, then centre it.
    for (var tries = 0; tries < 60; tries++) {
      final ctx = _messageKeys[messageId]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.4,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
        break;
      }
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final next = (pos.pixels + pos.viewportDimension * 0.8).clamp(0.0, pos.maxScrollExtent);
      if (next == pos.pixels) break;
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    setState(() => _highlightId = messageId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  Future<bool> _schedule(String text) async {
    final st = _bloc.state;
    final at = await pickScheduleTime(context);
    if (at == null || !mounted) return false;
    final r = await sl<ChatTools>().schedule(
      ScheduledMessage(
        id: '',
        chatId: st.chatId,
        senderId: st.me!.id,
        text: text,
        sendAt: at,
        isGroup: st.isGroup,
        participants: st.participants.isNotEmpty ? st.participants : [st.me!.id, if (st.peer != null) st.peer!.id],
      ),
    );
    if (!mounted) return false;
    return r.fold(
      (f) {
        AppFeedback.error(context, f.message);
        return false;
      },
      (_) {
        AppFeedback.info(context, tr('Message scheduled'));
        return true;
      },
    );
  }

  Future<void> _onAttach() async {
    final kind = await showAttachmentSheet(context);
    if (kind == null || !mounted) return;
    final picker = sl<MediaPickerService>();
    try {
      switch (kind) {
        case AttachmentKind.viewOncePhoto:
          final f = await picker.pickImage();
          if (f != null) await _previewAndSend([f], viewOnce: true);
        case AttachmentKind.gallery:
          await _previewAndSend(await picker.pickMultiImages());
        case AttachmentKind.camera:
          await _onCamera();
        case AttachmentKind.video:
          final f = await picker.pickVideo();
          if (f != null) _bloc.add(MediaMessageSent(type: MessageType.video, file: f));
        case AttachmentKind.document:
          final picked = await picker.pickDocument();
          if (picked != null) {
            _bloc.add(
              MediaMessageSent(type: MessageType.file, file: picked.file, fileName: picked.name, fileSize: picked.size),
            );
          }
        case AttachmentKind.location:
          final loc = await picker.currentLocation();
          _bloc.add(LocationMessageSent(loc.latitude, loc.longitude));
        case AttachmentKind.poll:
          final poll = await showCreatePollSheet(context);
          if (poll != null) _bloc.add(PollSent(poll));
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e is String ? e : tr('Could not attach that file.'));
    }
  }

  /// Preview → (draw / text / rotate / caption / view once) → send.
  Future<void> _previewAndSend(List<File> files, {bool viewOnce = false}) async {
    if (files.isEmpty || !mounted) return;
    final res = await openPhotoPreview(context, files, viewOnce: viewOnce);
    if (res == null || !mounted) return;
    for (final (i, f) in res.files.indexed) {
      _bloc.add(
        MediaMessageSent(type: MessageType.image, file: f, caption: i == 0 ? res.caption : '', viewOnce: res.viewOnce),
      );
    }
  }

  /// Camera button: take a photo, scan a document (→ PDF), or pick from gallery.
  Future<void> _onCamera() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                  title: Text(tr('Take photo')),
                  onTap: () => Navigator.pop(ctx, 'photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                  title: Text(tr('Scan document')),
                  subtitle: Text(tr('Sent as a PDF')),
                  onTap: () => Navigator.pop(ctx, 'scan'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  title: Text(tr('Choose from gallery')),
                  onTap: () => Navigator.pop(ctx, 'gallery'),
                ),
              ],
            ),
          ),
    );
    if (choice == null || !mounted) return;
    final picker = sl<MediaPickerService>();
    try {
      switch (choice) {
        case 'photo':
          final f = await picker.pickImage(camera: true);
          if (f != null) await _previewAndSend([f]);
        case 'gallery':
          await _previewAndSend(await picker.pickMultiImages());
        case 'scan':
          final result = await CunningDocumentScanner.scanDocuments(
            noOfPages: 30,
            scannerSource: ScannerSource.cameraAndGallery,
            output: ScanOutput.pdf,
          );
          final pdf = result?.pdf;
          if (pdf == null) return;
          final file = File(pdf);
          final name = tr('Scan {0}.pdf', [DateFormat('yyyy-MM-dd HH.mm').format(DateTime.now())]);
          _bloc.add(
            MediaMessageSent(type: MessageType.file, file: file, fileName: name, fileSize: await file.length()),
          );
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, tr('Could not open the camera or scanner.'));
    }
  }

  Future<void> _onLongPress(MessageEntity m, ConversationState state) async {
    final myId = state.me!.id;
    final result = await showMessageActions(
      context,
      message: m,
      isMine: m.isMine(myId),
      myReaction: m.reactions[myId],
      isPinned: state.chat?.pinnedMessages.any((p) => p.messageId == m.id) ?? false,
      canPin: state.isMember && state.chat != null,
      isStarred: sl<StarredStore>().isStarred(m.chatId, m.id),
      // Member → member in a group, only when both are public (not anonymous).
      canReplyPrivately:
          state.isGroup &&
          !m.isMine(myId) &&
          m.type != MessageType.system &&
          !(state.chat?.isAnonymous(m.senderId) ?? true) &&
          !state.amAnonymous,
    );
    if (result == null || !mounted) return;
    if (result.emoji != null) {
      _bloc.add(MessageReacted(m, result.emoji!));
      return;
    }
    switch (result.action) {
      case MessageAction.reply:
        _bloc.add(ReplyTargetChanged(m));
      case MessageAction.forward:
        await showForwardSheet(context, m);
      case MessageAction.replyPrivately:
        context.push(
          AppRoutes.conversation(IdUtils.directChatId(myId, m.senderId)),
          extra: ConversationArgs(replyTo: m),
        );
      case MessageAction.star:
      case MessageAction.unstar:
        await sl<StarredStore>().toggle(m, chatTitle: state.title, senderName: state.nameOf(m.senderId));
      case MessageAction.addAppointment:
        await showAppointmentEditor(context, initialTitle: m.text, chatId: state.chatId);
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: m.text));
        if (mounted) AppFeedback.info(context, tr('Copied to clipboard'));
      case MessageAction.edit:
        _bloc.add(EditTargetChanged(m));
      case MessageAction.pin:
        final r = await sl<ChatTools>().pin(state.chatId, m, myId);
        if (mounted)
          r.match((f) => AppFeedback.error(context, f.message), (_) => AppFeedback.info(context, tr('Message pinned')));
      case MessageAction.unpin:
        await sl<ChatTools>().unpin(state.chatId, m.id);
      case MessageAction.deleteForMe:
        _bloc.add(MessageDeleted(m, forEveryone: false));
      case MessageAction.deleteForEveryone:
        final ok = await AppFeedback.confirm(
          context,
          title: tr('Delete for everyone?'),
          message: tr('This message will be removed for all participants.'),
          confirmLabel: tr('Delete'),
          destructive: true,
        );
        if (ok) _bloc.add(MessageDeleted(m, forEveryone: true));
      case MessageAction.info:
        _showInfo(m, state);
      case MessageAction.moreReactions:
        final emoji = await showEmojiPickerSheet(context);
        if (emoji != null && mounted) _bloc.add(MessageReacted(m, emoji));
      case null:
        break;
    }
  }

  void _showInfo(MessageEntity m, ConversationState state) {
    final others = state.participants.where((p) => p != state.me!.id).toList();
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(tr('Message info'), style: ctx.text.titleLarge),
                ),
                for (final uid in others)
                  ListTile(
                    leading: AppAvatar(name: state.nameOf(uid), imageUrl: state.photoOf(uid), size: 40),
                    title: Text(state.nameOf(uid)),
                    trailing: DeliveryTicks(
                      status:
                          m.readBy.contains(uid)
                              ? DeliveryStatus.read
                              : m.deliveredTo.contains(uid)
                              ? DeliveryStatus.delivered
                              : DeliveryStatus.sent,
                      color: ctx.palette.textSecondary,
                      readColor: AppColors.primary,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the block list changes (block / unblock from the menu).
    return ListenableBuilder(
      listenable: Listenable.merge([sl<BlockList>(), sl<StarredStore>()]),
      builder:
          (context, _) => BlocConsumer<ConversationBloc, ConversationState>(
            listenWhen: (p, c) => c.error != null && p.error != c.error,
            listener: (context, state) => AppFeedback.error(context, state.error!),
            builder: (context, state) {
              final me = state.me;
              if (me == null) return const Scaffold();
              return Scaffold(
                appBar: _ConversationAppBar(state: state),
                body: ChatWallpaper(
                  chatId: state.chatId,
                  child: Column(
                    children: [
                      if (state.chat != null && state.chat!.pinnedMessages.isNotEmpty)
                        PinnedMessagesBanner(
                          pins: state.chat!.pinnedMessages,
                          nameOf: state.nameOf,
                          onJump: _jumpTo,
                          onUnpin: state.isMember ? (id) => sl<ChatTools>().unpin(state.chatId, id) : null,
                        ),
                      ScheduledMessagesBar(chatId: state.chatId, uid: me.id),
                      Expanded(
                        child: Stack(
                          children: [
                            ReadReceiptsScope(
                              // Read receipts off → no blue ticks in 1:1 chats (groups always show them).
                              enabled: state.isGroup || me.readReceipts,
                              child: _MessageList(
                                state: state,
                                controller: _scroll,
                                onReply: (m) => _bloc.add(ReplyTargetChanged(m)),
                                onLongPress: (m) => _onLongPress(m, state),
                                keyFor: _keyFor,
                                highlightId: _highlightId,
                                onJump: _jumpTo,
                              ),
                            ),
                            Positioned(
                              right: 14,
                              bottom: 14,
                              child: AnimatedScale(
                                scale: _showScrollDown ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: FloatingActionButton.small(
                                  heroTag: null,
                                  backgroundColor: context.palette.surfaceHigh,
                                  foregroundColor: context.colors.onSurface,
                                  onPressed:
                                      () => _scroll.animateTo(
                                        0,
                                        duration: const Duration(milliseconds: 400),
                                        curve: Curves.easeOutCubic,
                                      ),
                                  child: const Icon(Icons.keyboard_double_arrow_down_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!state.isGroup && sl<BlockList>().isBlocked(state.peer?.id))
                        _BlockedBar(
                          name: state.peer!.name,
                          onUnblock: () => ChatActions.toggleBlock(context, state.peer!.id, state.peer!.name),
                        )
                      else if (state.isMember && !(state.chat?.closed ?? false))
                        Composer(
                          replyingTo: state.replyingTo,
                          replyingToName: state.replyingTo == null ? null : state.nameOf(state.replyingTo!.senderId),
                          editing: state.editing,
                          onCancelReplyOrEdit: () {
                            _bloc
                              ..add(const ReplyTargetChanged(null))
                              ..add(const EditTargetChanged(null));
                          },
                          onSend: (text) {
                            _bloc.add(TextMessageSent(text));
                            if (_scroll.hasClients && _scroll.offset > 0) {
                              _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                            }
                          },
                          onTypingChanged: (t) => _bloc.add(TypingChanged(t)),
                          onSchedule: _schedule,
                          onAttach: _onAttach,
                          onCamera: _onCamera,
                          onSticker: (id) => _bloc.add(StickerSent(id)),
                          onCustomSticker: (file) => _bloc.add(MediaMessageSent(type: MessageType.sticker, file: file)),
                          onVoiceRecorded:
                              (rec, viewOnce) => _bloc.add(
                                MediaMessageSent(
                                  type: MessageType.audio,
                                  file: rec.file,
                                  duration: rec.duration,
                                  waveform: rec.waveform,
                                  viewOnce: viewOnce,
                                ),
                              ),
                        )
                      else
                        _NotMemberBar(state: state),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

class _ConversationAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ConversationAppBar({required this.state});
  final ConversationState state;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  String _subtitle() {
    if (state.isGroup) {
      final names = state.participants.map((p) => state.nameOf(p)).where((n) => n != 'Unknown').take(6).join(', ');
      return names;
    }
    final peer = state.peer;
    final me = state.me;
    if (peer == null || me == null) return '';
    if (sl<BlockList>().isBlocked(peer.id)) return '';
    // If I hide my online / last seen, I can't see other people's either.
    if (peer.isOnline && !me.hideOnline) return tr('online');
    if (me.hideLastSeen || peer.lastSeen == null) return '';
    return Formatters.lastSeen(peer.lastSeen);
  }

  void _openInfo(BuildContext context) {
    if (state.isGroup) {
      context.push(AppRoutes.groupInfo(state.chatId));
    } else if (state.peer != null) {
      context.push(AppRoutes.userProfile(state.peer!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typing = state.typingNames;
    final subtitle = _subtitle();
    return AppBar(
      titleSpacing: 0,
      toolbarHeight: 64,
      title: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openInfo(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AppAvatar(
                name: state.title,
                imageUrl: state.photoUrl,
                size: 42,
                isGroup: state.isGroup,
                isOnline: state.peer?.isOnline ?? false,
                heroTag: 'avatar-${state.chatId}',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child:
                          typing.isNotEmpty
                              ? TypingLabel(
                                key: const ValueKey('typing'),
                                text: state.isGroup ? tr('{0} typing', [typing.join(', ')]) : tr('typing'),
                                color: AppColors.accent,
                                fontSize: 12.5,
                              )
                              : subtitle.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                subtitle,
                                key: ValueKey(subtitle),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: subtitle == tr('online') ? AppColors.online : context.palette.textSecondary,
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (state.isMember && state.chat != null) ...[
          IconButton(
            tooltip: tr('Video call'),
            onPressed:
                () => CallLauncher.start(context, chat: state.chat!, users: state.displayUsers, type: CallType.video),
            icon: const Icon(Icons.videocam_rounded),
          ),
          IconButton(
            tooltip: tr('Voice call'),
            onPressed:
                () => CallLauncher.start(context, chat: state.chat!, users: state.displayUsers, type: CallType.voice),
            icon: const Icon(Icons.call_rounded),
          ),
        ],
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'info':
                _openInfo(context);
              case 'media':
                context.push(AppRoutes.chatMedia(state.chatId));
              case 'wallpaper':
                context.push(tr('{0}?chatId={1}', [AppRoutes.wallpaper, state.chatId]));
              case 'scheduled':
                showScheduledMessagesSheet(context, uid: state.me!.id, chatId: state.chatId);
              case 'mute':
                if (state.chat != null) ChatActions.toggleMute(context, state.chat!, state.me!.id);
              case 'clear':
                ChatActions.clearChat(context, state.chatId, state.me!.id);
              case 'autoclear':
                if (state.chat != null) ChatActions.toggleAutoClear(context, state.chat!, state.me!.id);
              case 'starred':
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => StarredMessagesPage(chatId: state.chatId)));
              case 'export':
                exportChat(context, state);
              case 'delete':
                ChatActions.deleteChat(context, state.chatId, state.me!.id);
              case 'block':
                if (state.peer != null) ChatActions.toggleBlock(context, state.peer!.id, state.peer!.name);
            }
          },
          itemBuilder: (_) {
            final muted = state.chat?.isMutedFor(state.me!.id) ?? false;
            final blocked = sl<BlockList>().isBlocked(state.peer?.id);
            return [
              PopupMenuItem(value: 'info', child: Text(state.isGroup ? tr('Group info') : tr('View contact'))),
              PopupMenuItem(value: 'media', child: Text(tr('Media, links and docs'))),
              PopupMenuItem(value: 'scheduled', child: Text(tr('Scheduled messages'))),
              if (state.chat != null)
                PopupMenuItem(
                  value: 'mute',
                  child: Text(muted ? tr('Unmute notifications') : tr('Mute notifications')),
                ),
              PopupMenuItem(value: 'wallpaper', child: Text(tr('Wallpaper'))),
              PopupMenuItem(value: 'starred', child: Text(tr('Starred messages'))),
              PopupMenuItem(value: 'clear', child: Text(tr('Clear chat'))),
              if (state.chat != null)
                PopupMenuItem(
                  value: 'autoclear',
                  child: Text(
                    (state.chat!.autoClearsFor(state.me!.id)) ? tr('Daily auto-clear: on') : tr('Clear chat daily'),
                  ),
                ),
              PopupMenuItem(value: 'export', child: Text(tr('Export chat'))),
              if (!state.isGroup) PopupMenuItem(value: 'delete', child: Text(tr('Delete chat'))),
              if (!state.isGroup && state.peer != null)
                PopupMenuItem(value: 'block', child: Text(blocked ? tr('Unblock') : tr('Block'))),
            ];
          },
        ),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.controller,
    required this.onReply,
    required this.onLongPress,
    required this.keyFor,
    required this.highlightId,
    required this.onJump,
  });

  final ConversationState state;
  final ScrollController controller;
  final ValueChanged<MessageEntity> onReply;
  final ValueChanged<MessageEntity> onLongPress;
  final GlobalKey Function(String messageId) keyFor;
  final String? highlightId;
  final ValueChanged<String> onJump;

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _grouped(MessageEntity a, MessageEntity? b) {
    if (b == null) return false;
    if (a.senderId != b.senderId) return false;
    if (a.type == MessageType.system || b.type == MessageType.system) return false;
    final ta = a.createdAt, tb = b.createdAt;
    if (ta == null || tb == null) return true;
    return ta.difference(tb).abs() < const Duration(minutes: 5) && _sameDay(ta, tb);
  }

  @override
  Widget build(BuildContext context) {
    final messages = state.messages;
    final uploads = state.uploads.reversed.toList();
    final me = state.me!.id;

    if (state.status == ConversationStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty && uploads.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.palette.surfaceHigh.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👋', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(tr('Say hello!'), style: context.text.titleMedium),
              const SizedBox(height: 4),
              Text(tr('Messages are delivered in real time.'), style: TextStyle(color: context.palette.textSecondary)),
            ],
          ),
        ),
      );
    }

    final total = uploads.length + messages.length + (state.isLoadingMore ? 1 : 0);
    return ListView.builder(
      controller: controller,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      itemCount: total,
      itemBuilder: (context, index) {
        if (index < uploads.length) return UploadBubble(upload: uploads[index]);
        final i = index - uploads.length;
        if (i >= messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = messages[i];
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final newer = i > 0 ? messages[i - 1] : null;
        final showDate = m.createdAt != null && (older == null || !_sameDay(m.createdAt, older.createdAt));

        final bubble = MessageBubble(
          key: ValueKey(m.id),
          message: m,
          myId: me,
          participants: state.participants,
          isGroup: state.isGroup,
          isFirstInGroup: !_grouped(m, older) || showDate,
          isLastInGroup: !_grouped(m, newer),
          senderName: state.nameOf(m.senderId),
          senderPhoto: state.photoOf(m.senderId),
          onReply: () => onReply(m),
          onLongPress: () => onLongPress(m),
          onReactionTap: () => _showReactions(context, m),
          onPollVote: (ids) => context.read<ConversationBloc>().add(PollVoted(m, ids)),
          nameOf: state.nameOf,
          onReplyTap: m.replyTo == null ? null : () => onJump(m.replyTo!.messageId),
          onOpenViewOnce:
              () => openViewOnce(context, m, onOpened: () => sl<ChatTools>().markOpened(state.chatId, m.id, me)),
          isStarred: sl<StarredStore>().isStarred(m.chatId, m.id),
          onReview:
              (state.chat?.isAdmin(me) ?? false) && m.pendingApproval && !m.isMine(me)
                  ? (approve) => sl<GroupMembership>().reviewMedia(state.chatId, m.id, me, approve: approve)
                  : null,
        );

        // Keyed so "jump to message" can find it; flashes when highlighted.
        final target = AnimatedContainer(
          key: keyFor(m.id),
          duration: const Duration(milliseconds: 300),
          color: highlightId == m.id ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
          child: bubble,
        );
        if (!showDate) return target;
        return Column(children: [DateChip(date: m.createdAt!), target]);
      },
    );
  }

  void _showReactions(BuildContext context, MessageEntity m) {
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in m.reactions.entries)
                  ListTile(
                    leading: AppAvatar(name: state.nameOf(e.key), imageUrl: state.photoOf(e.key), size: 40),
                    title: Text(state.nameOf(e.key)),
                    subtitle: e.key == state.me!.id ? Text(tr('Tap to remove')) : null,
                    trailing: Text(e.value, style: const TextStyle(fontSize: 24)),
                    onTap:
                        e.key == state.me!.id
                            ? () {
                              context.read<ConversationBloc>().add(MessageReacted(m, e.value));
                              Navigator.pop(ctx);
                            }
                            : null,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }
}

/// Shown instead of the composer when I blocked this contact.
class _BlockedBar extends StatelessWidget {
  const _BlockedBar({required this.name, required this.onUnblock});
  final String name;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) => Material(
    color: context.theme.scaffoldBackgroundColor,
    child: InkWell(
      onTap: onUnblock,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: Text.rich(
          TextSpan(
            text: tr('You blocked {0}. ', [name]),
            style: TextStyle(color: context.palette.textSecondary),
            children: [
              TextSpan(
                text: tr('Tap to unblock.'),
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// Instead of the composer: the group ended, or I left (with "Rejoin" when
/// the group isn't secret), or I was removed.
class _NotMemberBar extends StatelessWidget {
  const _NotMemberBar({required this.state});
  final ConversationState state;

  Future<void> _rejoin(BuildContext context) async {
    final me = state.me!;
    final chat = state.chat!;
    final choice = await chooseJoinIdentity(
      context,
      groupName: chat.name ?? tr('Group'),
      myName: me.name,
      myPhotoUrl: me.photoUrl,
    );
    if (choice == null || !context.mounted) return;
    final r = await sl<GroupMembership>().rejoin(chat.id, me.id, me.name, alias: choice.alias);
    if (context.mounted)
      r.match((f) => AppFeedback.error(context, f.message), (_) => AppFeedback.info(context, tr('Welcome back')));
  }

  @override
  Widget build(BuildContext context) {
    final chat = state.chat;
    final me = state.me?.id ?? '';
    final String text;
    if (chat?.closed ?? false) {
      text = tr('This group has ended. No one can send messages anymore.');
    } else if (chat?.isFormerMember(me) ?? false) {
      text =
          chat!.secret
              ? tr('You left this secret group. An admin has to invite you to come back.')
              : tr('You left this group.');
    } else {
      text = tr('You can\'t send messages to this group because you\'re no longer a member.');
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
      color: context.theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.palette.textSecondary)),
          if (chat != null && chat.canRejoin(me)) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _rejoin(context),
              icon: const Icon(Icons.group_add_rounded),
              label: Text(tr('Rejoin group')),
            ),
          ],
          if (chat != null && chat.isGroup)
            TextButton.icon(
              onPressed: () => ChatActions.deleteChat(context, chat.id, me),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(tr('Delete group')),
            ),
        ],
      ),
    );
  }
}
