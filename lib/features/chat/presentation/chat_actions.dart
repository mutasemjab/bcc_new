import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../users/presentation/block_list.dart';
import '../domain/entities/chat_entity.dart';
import '../domain/usecases/chat_extras.dart';
import '../domain/usecases/chat_usecases.dart';

/// Chat-level actions shared by the chat screen, contact info and group info.
abstract final class ChatActions {
  static Future<void> toggleMute(BuildContext context, ChatEntity chat, String me) async {
    final mute = !chat.isMutedFor(me);
    final r = await sl<ToggleMuteChat>()((chat.id, me, mute));
    if (!context.mounted) return;
    r.match(
      (f) => AppFeedback.error(context, f.message),
      (_) => AppFeedback.info(context, mute ? 'Notifications muted' : 'Notifications unmuted'),
    );
  }

  static Future<void> clearChat(BuildContext context, String chatId, String me) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Clear this chat?',
      message: 'All messages will be removed from this chat for you. Others will still see them.',
      confirmLabel: 'Clear chat',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final r = await sl<ChatTools>().clearChat(chatId, me);
    if (context.mounted)
      r.match((f) => AppFeedback.error(context, f.message), (_) => AppFeedback.info(context, 'Chat cleared'));
  }

  static Future<void> deleteChat(BuildContext context, String chatId, String me) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Delete this chat?',
      message: 'The chat and its messages will be deleted for you. It comes back if a new message arrives.',
      confirmLabel: 'Delete chat',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final r = await sl<ChatTools>().deleteChat(chatId, me);
    if (!context.mounted) return;
    r.match((f) => AppFeedback.error(context, f.message), (_) => context.go(AppRoutes.home));
  }

  /// Block or unblock [otherId] (asks first when blocking).
  static Future<void> toggleBlock(BuildContext context, String otherId, String otherName) async {
    final list = sl<BlockList>();
    if (list.isBlocked(otherId)) {
      final err = await list.unblock(otherId);
      if (context.mounted) AppFeedback.info(context, err ?? '$otherName unblocked');
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: 'Block $otherName?',
      message:
          'Blocked contacts can no longer call you or send you messages, '
          'and they won\'t see when you\'re online or your last seen.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = await list.block(otherId);
    if (context.mounted) AppFeedback.info(context, err ?? '$otherName blocked');
  }

  static Future<void> toggleAutoClear(BuildContext context, ChatEntity chat, String me) async {
    final on = !chat.autoClearsFor(me);
    if (on) {
      final ok = await AppFeedback.confirm(
        context,
        title: 'Clear this chat every day?',
        message: 'Every day the chat will be cleared automatically — for you only. Others keep their messages.',
        confirmLabel: 'Turn on',
      );
      if (!ok || !context.mounted) return;
    }
    final r = await sl<ChatTools>().setAutoClear(chat.id, me, on);
    if (context.mounted) {
      r.match(
        (f) => AppFeedback.error(context, f.message),
        (_) => AppFeedback.info(context, on ? 'Daily auto-clear is on' : 'Daily auto-clear is off'),
      );
    }
  }
}
