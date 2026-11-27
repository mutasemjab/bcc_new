import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/di.dart';
import '../../../core/widgets/app_feedback.dart';
import '../domain/entities/message_entity.dart';
import '../domain/usecases/chat_extras.dart';
import 'bloc/conversation/conversation_bloc.dart';

/// "Export chat" — writes the conversation to a .txt file (like WhatsApp)
/// and opens the share sheet (email, Drive, WhatsApp, Files…).
Future<void> exportChat(BuildContext context, ConversationState state) async {
  final withMedia = await showModalBottomSheet<bool>(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_snippet_rounded),
                title: Text(tr('Without media')),
                subtitle: Text(tr('Text messages only')),
                onTap: () => Navigator.pop(ctx, false),
              ),
              ListTile(
                leading: const Icon(Icons.perm_media_rounded),
                title: Text(tr('Include media links')),
                subtitle: Text(tr('Photos, videos and files as download links')),
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
  );
  if (withMedia == null || !context.mounted) return;

  AppFeedback.info(context, tr('Preparing export…'));
  final r = await sl<ChatTools>().fullHistory(state.chatId);
  if (!context.mounted) return;
  final all = r.fold((f) {
    AppFeedback.error(context, f.message);
    return null;
  }, (m) => m);
  if (all == null) return;

  final me = state.me!.id;
  final cleared = state.chat?.clearedAt[me];
  final visible =
      all
          .where((m) => !m.isHiddenFor(me) && !m.rejected && (!m.pendingApproval || m.isMine(me)))
          .where((m) => cleared == null || (m.createdAt?.isAfter(cleared) ?? true))
          .toList();

  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final buf =
      StringBuffer()
        ..writeln(tr('BCC Chat — {0}', [state.title]))
        ..writeln(tr('Exported {0} • {1} messages', [fmt.format(DateTime.now()), visible.length]))
        ..writeln();
  for (final m in visible) {
    final when = m.createdAt == null ? '' : fmt.format(m.createdAt!);
    if (m.type == MessageType.system) {
      buf.writeln('[$when] — ${m.text}');
      continue;
    }
    final who = state.nameOf(m.senderId);
    final body = StringBuffer(m.preview);
    if (withMedia && !m.viewOnce && m.mediaUrl != null) body.write('  ${m.mediaUrl}');
    if (m.type == MessageType.text && m.isForwarded) body.write(tr('  (forwarded)'));
    buf.writeln('[$when] $who: $body');
  }

  final dir = await getTemporaryDirectory();
  final safe = state.title.replaceAll(RegExp(r'[^\w؀-ۿ -]'), '').trim();
  final file = File('${dir.path}/BCC Chat - ${safe.isEmpty ? 'chat' : safe}.txt');
  await file.writeAsString(buf.toString());
  if (!context.mounted) return;
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Chat with ${state.title}'));
}
