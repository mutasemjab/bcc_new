import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable.dart';
import '../../domain/entities/message_entity.dart';

enum AttachmentKind { gallery, viewOncePhoto, camera, video, document, location, poll }

/// Colourful grid of attachment options.
Future<AttachmentKind?> showAttachmentSheet(BuildContext context) {
  const items = [
    (AttachmentKind.gallery, 'Gallery', Icons.photo_library_rounded, [Color(0xFF7B61FF), Color(0xFFB98BFF)]),
    (AttachmentKind.viewOncePhoto, 'View once', Icons.looks_one_rounded, [Color(0xFF2479B5), Color(0xFF3A9AD9)]),
    (AttachmentKind.camera, 'Camera', Icons.photo_camera_rounded, [Color(0xFFFF4D6D), Color(0xFFFF8FA3)]),
    (AttachmentKind.video, 'Video', Icons.videocam_rounded, [Color(0xFFFF8A3D), Color(0xFFFFB27A)]),
    (AttachmentKind.document, 'Document', Icons.description_rounded, [Color(0xFF2479B5), Color(0xFF84C4EB)]),
    (AttachmentKind.location, 'Location', Icons.location_on_rounded, [Color(0xFF00B8A9), Color(0xFF5CE1D6)]),
    (AttachmentKind.poll, 'Poll', Icons.poll_rounded, [Color(0xFF5A5A5C), Color(0xFF8E8E93)]),
  ];
  return showModalBottomSheet<AttachmentKind>(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 22,
              spacing: 18,
              children: [
                for (final (i, item) in items.indexed)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 260 + i * 60),
                    curve: Curves.easeOutBack,
                    builder: (_, t, c) => Transform.scale(scale: t, child: c),
                    child: Pressable(
                      onTap: () => Navigator.pop(ctx, item.$1),
                      child: SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: item.$4,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: item.$4.first.withValues(alpha: 0.4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(item.$3, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(item.$2, style: ctx.text.labelMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
  );
}

enum MessageAction {
  reply,
  replyPrivately,
  forward,
  copy,
  edit,
  star,
  unstar,
  pin,
  unpin,
  addAppointment,
  deleteForMe,
  deleteForEveryone,
  info,
  moreReactions,
}

/// Like WhatsApp: "Delete for everyone" is possible for a limited time.
const kDeleteForEveryoneWindow = Duration(hours: 2);
const kEditWindow = Duration(minutes: 15);

class MessageActionResult {
  const MessageActionResult({this.action, this.emoji});
  final MessageAction? action;
  final String? emoji;
}

const kQuickReactions = ['❤️', '😂', '😮', '😢', '🙏', '👍'];

/// Reaction bar + context actions for a long-pressed message.
Future<MessageActionResult?> showMessageActions(
  BuildContext context, {
  required MessageEntity message,
  required bool isMine,
  required String? myReaction,
  bool isPinned = false,
  bool canPin = true,
  bool isStarred = false,
  bool canReplyPrivately = false,
}) {
  final canEdit =
      isMine &&
      message.type == MessageType.text &&
      !message.deletedForEveryone &&
      message.createdAt != null &&
      DateTime.now().difference(message.createdAt!) < kEditWindow;
  final canDeleteForEveryone =
      isMine &&
      !message.deletedForEveryone &&
      message.createdAt != null &&
      DateTime.now().difference(message.createdAt!) < kDeleteForEveryoneWindow;
  final canForward =
      !message.deletedForEveryone &&
      !message.viewOnce &&
      message.type != MessageType.poll &&
      message.type != MessageType.system;

  return showModalBottomSheet<MessageActionResult>(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!message.deletedForEveryone)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: ctx.palette.surfaceHigh, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final (i, e) in kQuickReactions.indexed)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 250 + i * 50),
                          curve: Curves.elasticOut,
                          builder: (_, t, c) => Transform.scale(scale: t, child: c),
                          child: Pressable(
                            scale: 1.3,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(ctx, MessageActionResult(emoji: e));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: myReaction == e ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                        ),
                      // Any emoji: opens the full picker.
                      Pressable(
                        onTap: () => Navigator.pop(ctx, const MessageActionResult(action: MessageAction.moreReactions)),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                myReaction != null && !kQuickReactions.contains(myReaction)
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : ctx.theme.scaffoldBackgroundColor,
                          ),
                          alignment: Alignment.center,
                          child:
                              myReaction != null && !kQuickReactions.contains(myReaction)
                                  ? Text(myReaction, style: const TextStyle(fontSize: 22))
                                  : Icon(Icons.add_rounded, color: ctx.palette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!message.deletedForEveryone) _action(ctx, Icons.reply_rounded, 'Reply', MessageAction.reply),
              if (canReplyPrivately)
                _action(ctx, Icons.quickreply_rounded, 'Reply privately', MessageAction.replyPrivately),
              if (canForward) _action(ctx, Icons.shortcut_rounded, 'Forward', MessageAction.forward),
              if (!message.deletedForEveryone && message.type != MessageType.system)
                isStarred
                    ? _action(ctx, Icons.star_border_rounded, 'Unstar', MessageAction.unstar)
                    : _action(ctx, Icons.star_rounded, 'Star', MessageAction.star),
              if (message.type == MessageType.text && !message.deletedForEveryone)
                _action(ctx, Icons.event_available_rounded, 'Add to appointments', MessageAction.addAppointment),
              if (message.type == MessageType.text && !message.deletedForEveryone)
                _action(ctx, Icons.copy_rounded, 'Copy', MessageAction.copy),
              if (canEdit) _action(ctx, Icons.edit_rounded, 'Edit', MessageAction.edit),
              if (canPin && !message.deletedForEveryone && message.type != MessageType.system)
                isPinned
                    ? _action(ctx, Icons.push_pin_outlined, 'Unpin', MessageAction.unpin)
                    : _action(ctx, Icons.push_pin_rounded, 'Pin', MessageAction.pin),
              if (isMine && !message.deletedForEveryone)
                _action(ctx, Icons.info_outline_rounded, 'Info', MessageAction.info),
              _action(ctx, Icons.delete_outline_rounded, 'Delete for me', MessageAction.deleteForMe, danger: true),
              if (canDeleteForEveryone)
                _action(
                  ctx,
                  Icons.delete_forever_rounded,
                  'Delete for everyone',
                  MessageAction.deleteForEveryone,
                  danger: true,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
  );
}

Widget _action(BuildContext ctx, IconData icon, String label, MessageAction action, {bool danger = false}) {
  final color = danger ? AppColors.danger : null;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    onTap: () => Navigator.pop(ctx, MessageActionResult(action: action)),
  );
}

/// Full emoji keyboard in a sheet; returns the picked emoji.
Future<String?> showEmojiPickerSheet(BuildContext context) => showModalBottomSheet<String>(
  context: context,
  builder:
      (ctx) => SafeArea(
        child: SizedBox(
          height: 360,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) => Navigator.pop(ctx, emoji.emoji),
            config: Config(
              height: 360,
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: ctx.theme.scaffoldBackgroundColor,
                columns: 8,
                emojiSizeMax: 30,
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: ctx.theme.scaffoldBackgroundColor,
                indicatorColor: AppColors.primary,
                iconColorSelected: AppColors.primary,
              ),
              bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
              searchViewConfig: SearchViewConfig(backgroundColor: ctx.theme.scaffoldBackgroundColor),
            ),
          ),
        ),
      ),
);
