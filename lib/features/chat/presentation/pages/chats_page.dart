import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/entities/chat_entity.dart';
import '../bloc/chat_list/chat_list_bloc.dart';
import '../chat_actions.dart';
import '../email_invites.dart';
import '../widgets/chat_tile.dart';
import '../widgets/group_invitations.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatListBloc, ChatListState>(
      builder: (context, state) {
        final chats = state.visibleChats;
        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 108,
              backgroundColor: context.theme.scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                title: ShaderMask(
                  shaderCallback: (r) => AppColors.brandGradient.createShader(r),
                  child: Text(
                    'BCC Chat',
                    style: context.text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'New group',
                  onPressed: () => context.push(AppRoutes.newGroup),
                  icon: const Icon(Icons.group_add_rounded),
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: TextField(
                  onChanged: (q) => context.read<ChatListBloc>().add(ChatListSearchChanged(q)),
                  decoration: const InputDecoration(
                    hintText: 'Search chats',
                    prefixIcon: Icon(Icons.search_rounded),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _FilterChips(state: state)),
            const SliverToBoxAdapter(child: VerifyEmailBanner()),
            if (state.uid.isNotEmpty) SliverToBoxAdapter(child: GroupInvitationsSection(uid: state.uid)),
            if (state.status == ChatListStatus.loading || state.status == ChatListStatus.idle)
              const SliverFillRemaining(child: ChatListSkeleton())
            else if (chats.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.forum_rounded,
                  title: state.query.isNotEmpty || state.filter != ChatFilter.all ? 'Nothing here' : 'No chats yet',
                  message:
                      state.query.isNotEmpty
                          ? 'No chats match "${state.query}".'
                          : 'Start a conversation with friends and it will appear here.',
                  action:
                      state.query.isEmpty && state.filter == ChatFilter.all
                          ? SizedBox(
                            width: 220,
                            child: GradientButton(
                              label: 'Start a chat',
                              icon: Icons.add_comment_rounded,
                              onPressed: () => context.push(AppRoutes.newChat),
                            ),
                          )
                          : null,
                ),
              )
            else
              SliverList.builder(
                itemCount: chats.length,
                itemBuilder: (context, i) {
                  final chat = chats[i];
                  return _AnimatedEntry(
                    index: i,
                    child: ChatTile(
                      key: ValueKey(chat.id),
                      chat: chat,
                      myId: state.uid,
                      title: state.titleOf(chat),
                      photoUrl: state.photoOf(chat),
                      peer: state.peerOf(chat),
                      users: state.users,
                      onTap: () => context.push(AppRoutes.conversation(chat.id)),
                      onLongPress: () => _showChatOptions(context, chat, state),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }

  void _showChatOptions(BuildContext context, ChatEntity chat, ChatListState state) {
    final bloc = context.read<ChatListBloc>();
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(chat.isPinnedFor(state.uid) ? Icons.push_pin_outlined : Icons.push_pin_rounded),
                  title: Text(chat.isPinnedFor(state.uid) ? 'Unpin chat' : 'Pin chat'),
                  onTap: () {
                    bloc.add(ChatPinToggled(chat));
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(chat.isMutedFor(state.uid) ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                  title: Text(chat.isMutedFor(state.uid) ? 'Unmute notifications' : 'Mute notifications'),
                  onTap: () {
                    bloc.add(ChatMuteToggled(chat));
                    Navigator.pop(ctx);
                  },
                ),
                // Ended group, or one I left → remove it from my list.
                if (chat.isGroup && (chat.closed || !chat.participants.contains(state.uid)))
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: const Text('Delete group', style: TextStyle(color: AppColors.danger)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ChatActions.deleteChat(context, chat.id, state.uid);
                    },
                  ),
                if (chat.isGroup)
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Group info'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.groupInfo(chat.id));
                    },
                  )
                else if (chat.peerId(state.uid) != null)
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('View contact'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.userProfile(chat.peerId(state.uid)!));
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state});
  final ChatListState state;

  @override
  Widget build(BuildContext context) {
    final unreadCount = state.chats.where((c) => c.unreadFor(state.uid) > 0).length;
    final items = [
      (ChatFilter.all, 'All'),
      (ChatFilter.unread, unreadCount > 0 ? 'Unread  $unreadCount' : 'Unread'),
      (ChatFilter.groups, 'Groups'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          for (final (filter, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => context.read<ChatListBloc>().add(ChatListFilterChanged(filter)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: state.filter == filter ? AppColors.brandGradient : null,
                    color: state.filter == filter ? null : context.palette.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: state.filter == filter ? Colors.white : context.palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedEntry extends StatelessWidget {
  const _AnimatedEntry({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 10) * 40)),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c)),
      child: child,
    );
  }
}
