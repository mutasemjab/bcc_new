import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../chat/domain/entities/chat_entity.dart';
import '../../../chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../../domain/entities/call_entity.dart';
import '../bloc/call_log/call_log_cubit.dart';
import '../call_launcher.dart';

class CallsPage extends StatelessWidget {
  const CallsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ChatListBloc>().state;
    return BlocBuilder<CallLogCubit, CallLogState>(
      builder: (context, state) {
        final calls = state.visible;
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 108,
              backgroundColor: context.theme.scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                title: Text(tr('Calls'), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    selected: state.missedOnly,
                    label: Text(tr('Missed')),
                    onSelected: (_) => context.read<CallLogCubit>().toggleMissedOnly(),
                    selectedColor: AppColors.danger.withValues(alpha: 0.2),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                ),
              ],
            ),
            if (state.loading)
              const SliverFillRemaining(child: ChatListSkeleton(count: 6))
            else if (calls.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.call_rounded,
                  title: tr('No calls yet'),
                  message: tr('Voice and video calls with your friends and groups will show up here.'),
                ),
              )
            else
              SliverList.builder(
                itemCount: calls.length,
                itemBuilder: (context, i) {
                  final call = calls[i];
                  return _CallTile(call: call, state: state, chatState: chatState);
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call, required this.state, required this.chatState});
  final CallEntity call;
  final CallLogState state;
  final ChatListState chatState;

  @override
  Widget build(BuildContext context) {
    final me = state.uid;
    final outgoing = call.isOutgoingFor(me);
    final missed = state.isMissed(call);

    final peer = call.isGroup ? null : chatState.users[call.peerFor(me)];
    final name = call.isGroup ? call.title : (peer?.name ?? (outgoing ? '' : call.callerName));
    final photo = call.isGroup ? call.photoUrl : (peer?.photoUrl ?? (outgoing ? null : call.callerPhoto));

    final (dirIcon, dirColor) =
        outgoing
            ? (Icons.call_made_rounded, AppColors.online)
            : missed
            ? (Icons.call_missed_rounded, AppColors.danger)
            : (Icons.call_received_rounded, AppColors.online);

    final detail = [
      Formatters.chatListTime(call.createdAt),
      if (call.duration != null) Formatters.duration(call.duration!),
    ].join(' • ');

    final chat =
        chatState.chats.where((c) => c.id == call.chatId).firstOrNull ??
        ChatEntity(id: call.chatId, isGroup: call.isGroup, participants: call.participants, name: call.title);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: AppAvatar(name: name, imageUrl: photo, size: 50, isGroup: call.isGroup),
      title: Text(name, style: context.text.titleMedium?.copyWith(color: missed ? AppColors.danger : null)),
      subtitle: Row(
        children: [
          Icon(dirIcon, size: 16, color: dirColor),
          const SizedBox(width: 4),
          Expanded(child: Text(detail, style: TextStyle(color: context.palette.textSecondary))),
        ],
      ),
      trailing: IconButton(
        icon: Icon(call.isVideo ? Icons.videocam_rounded : Icons.call_rounded, color: AppColors.primary),
        onPressed: () => CallLauncher.start(context, chat: chat, users: chatState.users, type: call.type),
      ),
    );
  }
}
