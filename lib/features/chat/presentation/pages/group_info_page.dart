import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../calls/domain/entities/call_entity.dart';
import '../../../calls/presentation/call_launcher.dart';
import '../../../users/domain/entities/user_entity.dart';
import '../../../users/domain/usecases/user_usecases.dart';
import '../../../users/presentation/bloc/user_search/user_search_cubit.dart';
import '../../../users/presentation/widgets/user_tile.dart';
import '../../domain/usecases/chat_extras.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../../domain/usecases/group_usecases.dart';
import '../bloc/group/group_info_cubit.dart';
import '../../../../core/utils/id_utils.dart';
import '../chat_actions.dart';
import 'media_viewer_page.dart';
import '../email_invites.dart';
import '../widgets/group_identity_widgets.dart';
import 'create_group_page.dart';

class GroupInfoPage extends StatelessWidget {
  const GroupInfoPage({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionBloc>().state;
    if (session is! SessionAuthenticated) return const Scaffold();
    return BlocProvider(
      create:
          (_) => GroupInfoCubit(
            chatId: chatId,
            me: session.user,
            watchChat: sl<WatchChat>(),
            watchUsers: sl<WatchUsers>(),
            updateGroup: sl<UpdateGroup>(),
            addMembers: sl<AddGroupMembers>(),
            removeMember: sl<RemoveGroupMember>(),
            leaveGroup: sl<LeaveGroup>(),
            setAdmin: sl<SetGroupAdmin>(),
            membership: sl<GroupMembership>(),
          ),
      child: const _GroupInfoView(),
    );
  }
}

class _GroupInfoView extends StatelessWidget {
  const _GroupInfoView();

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(controller: controller, autofocus: true, maxLines: null),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
              TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(tr('Save'))),
            ],
          ),
    );
    controller.dispose();
    if (result != null) onSave(result);
  }

  Future<void> _addMembers(BuildContext context, GroupInfoCubit cubit) async {
    final selected = <UserEntity>[];
    final chosen = await Navigator.of(context).push<List<UserEntity>>(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider(
              create: (_) => UserSearchCubit(sl<SearchUsers>(), cubit.me.id),
              child: StatefulBuilder(
                builder:
                    (ctx, setState) => Scaffold(
                      appBar: AppBar(
                        title: Text(tr('Invite members')),
                        actions: [
                          TextButton(
                            onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected),
                            child: Text(tr('Invite{0}', [selected.isEmpty ? '' : ' (${selected.length})'])),
                          ),
                        ],
                      ),
                      body: MemberPicker(
                        excludeIds: {...?cubit.state.chat?.participants, ...?cubit.state.chat?.invited},
                        isSelected: (id) => selected.any((u) => u.id == id),
                        onToggle:
                            (u) => setState(() {
                              selected.any((s) => s.id == u.id)
                                  ? selected.removeWhere((s) => s.id == u.id)
                                  : selected.add(u);
                            }),
                      ),
                    ),
              ),
            ),
      ),
    );
    if (chosen != null && chosen.isNotEmpty) await cubit.addMembers(chosen);
  }

  Future<void> _inviteByEmail(BuildContext context, GroupInfoCubit cubit) async {
    final emails = await showEmailInviteSheet(context);
    if (emails == null || emails.isEmpty || !context.mounted) return;
    final res = await cubit.inviteByEmail(emails);
    if (res == null || !context.mounted) return;
    final chat = cubit.state.chat!;
    final send = await AppFeedback.confirm(
      context,
      title: tr('Invitations added'),
      message: tr(
        '{0} already on BCC Chat (they got the invitation in the app) • {1} without the app yet.\n\nSend them an invitation email now from your email app?',
        [res.existing, res.pending],
      ),
      confirmLabel: tr('Send email'),
    );
    if (!send || !context.mounted) return;
    await sendInvitationEmails(
      context,
      emails: emails,
      groupName: chat.name ?? tr('Group'),
      inviterName: cubit.myDisplayName,
      chatId: chat.id,
      inviteCode: chat.inviteCode,
    );
  }

  void _memberOptions(BuildContext context, GroupInfoCubit cubit, UserEntity user) {
    final chat = cubit.state.chat!;
    final isAdmin = chat.isAdmin(user.id);
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only admins can open a member's profile (number / email).
                if (cubit.isAdmin && !chat.isAnonymous(user.id))
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text(tr('View {0}', [user.name.split(' ').first])),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.userProfile(user.id));
                    },
                  ),
                // Direct message: only between two public (non-anonymous) people.
                if (!chat.isAnonymous(user.id) && !chat.isAnonymous(cubit.me.id))
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: Text(tr('Message {0}', [user.name.split(' ').first])),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.conversation(IdUtils.directChatId(cubit.me.id, user.id)));
                    },
                  ),
                if (cubit.isAdmin) ...[
                  ListTile(
                    leading: Icon(isAdmin ? Icons.remove_moderator_rounded : Icons.add_moderator_rounded),
                    title: Text(isAdmin ? tr('Dismiss as admin') : tr('Make group admin')),
                    subtitle:
                        !isAdmin && chat.isAnonymous(user.id)
                            ? Text(tr('Must reveal their identity first — admins are public'))
                            : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      cubit.toggleAdmin(user);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
                    title: Text(tr('Remove from group'), style: TextStyle(color: AppColors.danger)),
                    onTap: () {
                      Navigator.pop(ctx);
                      cubit.remove(user);
                    },
                  ),
                ],
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupInfoCubit, GroupInfoState>(
      listener: (context, state) {
        if (state.message != null) AppFeedback.info(context, state.message!);
        if (state.left) context.go(AppRoutes.home);
      },
      builder: (context, state) {
        final cubit = context.read<GroupInfoCubit>();
        final chat = state.chat;
        if (chat == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final members = state.sortedMembers();
        final amIMember = chat.participants.contains(cubit.me.id);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 320,
                actions: [
                  if (cubit.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      onPressed:
                          () => _editText(
                            context,
                            title: tr('Group name'),
                            initial: chat.name ?? '',
                            onSave: cubit.rename,
                          ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primary.withValues(alpha: 0.35), context.theme.scaffoldBackgroundColor],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 30),
                          Pressable(
                            // Admins: change the photo (long-press to view). Others: view it.
                            onTap:
                                cubit.isAdmin
                                    ? () async {
                                      final f = await sl<MediaPickerService>().pickImage();
                                      if (f != null) await cubit.setPhoto(f);
                                    }
                                    : chat.photoUrl == null
                                    ? null
                                    : () => MediaViewerPage.open(context, url: chat.photoUrl!, heroTag: 'group-photo'),
                            onLongPress:
                                chat.photoUrl == null
                                    ? null
                                    : () => MediaViewerPage.open(context, url: chat.photoUrl!, heroTag: 'group-photo'),
                            child: AppAvatar(
                              name: chat.name ?? tr('Group'),
                              imageUrl: chat.photoUrl,
                              size: 120,
                              isGroup: true,
                              heroTag: 'avatar-${chat.id}',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(chat.name ?? tr('Group'), style: context.text.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            tr('Group • {0} members', [chat.participants.length]),
                            style: TextStyle(color: context.palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      _ActionButton(
                        icon: Icons.call_rounded,
                        label: tr('Voice'),
                        onTap:
                            amIMember
                                ? () => CallLauncher.start(
                                  context,
                                  chat: chat,
                                  users: state.displayMembers,
                                  type: CallType.voice,
                                )
                                : null,
                      ),
                      const SizedBox(width: 12),
                      _ActionButton(
                        icon: Icons.videocam_rounded,
                        label: tr('Video'),
                        onTap:
                            amIMember
                                ? () => CallLauncher.start(
                                  context,
                                  chat: chat,
                                  users: state.displayMembers,
                                  type: CallType.video,
                                )
                                : null,
                      ),
                      const SizedBox(width: 12),
                      _ActionButton(
                        icon: Icons.person_add_alt_1_rounded,
                        label: tr('Invite'),
                        onTap: cubit.isAdmin ? () => _addMembers(context, cubit) : null,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Card(
                  child: ListTile(
                    title: Text(
                      (chat.description ?? '').isEmpty ? tr('Add group description') : chat.description!,
                      style: TextStyle(color: (chat.description ?? '').isEmpty ? AppColors.primary : null),
                    ),
                    subtitle: Text(
                      tr('Created by {0}', [
                        chat.createdBy == null ? '—' : state.displayUser(chat.createdBy!)?.name ?? '—',
                      ]),
                    ),
                    onTap:
                        cubit.isAdmin
                            ? () => _editText(
                              context,
                              title: tr('Description'),
                              initial: chat.description ?? '',
                              onSave: cubit.setDescription,
                            )
                            : null,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Card(
                  child: ListTile(
                    leading: const Icon(Icons.perm_media_rounded, color: AppColors.primary),
                    title: Text(tr('Media, links and docs')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.chatMedia(chat.id)),
                  ),
                ),
              ),
              if (amIMember)
                SliverToBoxAdapter(
                  child: _Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            chat.isMutedFor(cubit.me.id)
                                ? Icons.notifications_off_rounded
                                : Icons.notifications_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(tr('Mute notifications')),
                          trailing: Switch(
                            value: chat.isMutedFor(cubit.me.id),
                            onChanged: (_) => ChatActions.toggleMute(context, chat, cubit.me.id),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary),
                          title: Text(tr('Clear chat')),
                          onTap: () => ChatActions.clearChat(context, chat.id, cubit.me.id),
                        ),
                      ],
                    ),
                  ),
                ),
              if (amIMember) SliverToBoxAdapter(child: GroupIdentityCard(cubit: cubit, chat: chat)),
              if (cubit.isAdmin && !chat.closed)
                SliverToBoxAdapter(
                  child: _Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.lock_rounded, color: AppColors.primary),
                      title: Text(tr('Secret group')),
                      subtitle: Text(
                        tr('Members can\'t share the invite link, and members who leave can\'t rejoin on their own.'),
                      ),
                      value: chat.secret,
                      onChanged: cubit.setSecret,
                    ),
                  ),
                ),
              if (cubit.isAdmin && !chat.closed)
                SliverToBoxAdapter(
                  child: _Card(
                    child: ListTile(
                      leading: const Icon(Icons.alternate_email_rounded, color: AppColors.primary),
                      title: Text(tr('Invite by email')),
                      subtitle: Text(tr('Also for people who don\'t have the app yet')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _inviteByEmail(context, cubit),
                    ),
                  ),
                ),
              if (chat.canShareLink(cubit.me.id))
                SliverToBoxAdapter(
                  child: _Card(
                    child: ListTile(
                      leading: const Icon(Icons.link_rounded, color: AppColors.primary),
                      title: Text(tr('Invite via link')),
                      subtitle: Text(
                        chat.inviteCode == null ? tr('Create a link anyone can use to join') : tr('Link is active'),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showInviteLinkSheet(context, cubit),
                    ),
                  ),
                ),
              if (chat.pendingInviteCount > 0) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
                    child: Text(
                      tr('{0} PENDING INVITATIONS', [chat.pendingInviteCount]),
                      style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
                    ),
                  ),
                ),
                if (cubit.isAdmin)
                  SliverToBoxAdapter(
                    child: _Card(
                      child: Column(
                        children: [
                          for (final u in state.invitedUsers())
                            UserTile(
                              user: u,
                              subtitle: tr('Invited • waiting for answer'),
                              trailing: TextButton(onPressed: () => cubit.cancelInvite(u), child: Text(tr('Cancel'))),
                            ),
                          for (final e in chat.invitedEmails)
                            ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.alternate_email_rounded)),
                              title: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(tr('Invited by email • no account yet')),
                              trailing: TextButton(
                                onPressed: () => cubit.cancelEmailInvite(e),
                                child: Text(tr('Cancel')),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  // Members only see how many people were invited — not who.
                  SliverToBoxAdapter(
                    child: _Card(
                      child: ListTile(
                        leading: const Icon(Icons.hourglass_top_rounded),
                        title: Text(
                          chat.pendingInviteCount == 1
                              ? tr('1 person invited — waiting to join')
                              : tr('{0} people invited — waiting to join', [chat.pendingInviteCount]),
                        ),
                      ),
                    ),
                  ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
                  child: Text(
                    tr('{0} MEMBERS', [members.length]),
                    style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Card(
                  child: Column(
                    children: [
                      for (final m in members)
                        UserTile(
                          user: m,
                          subtitle:
                              m.id == cubit.me.id
                                  ? (chat.isAnonymous(m.id) ? tr('You • anonymous') : tr('You'))
                                  : chat.isAnonymous(m.id)
                                  ? tr('Anonymous member')
                                  : cubit.isAdmin
                                  ? [m.phone, m.email].whereType<String>().join(' • ')
                                  : '',
                          onTap: m.id == cubit.me.id ? null : () => _memberOptions(context, cubit, m),
                          trailing:
                              chat.isAdmin(m.id)
                                  ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tr('Admin'),
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                  : null,
                        ),
                    ],
                  ),
                ),
              ),
              if (chat.closed)
                SliverToBoxAdapter(
                  child: _Card(
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      title: Text(
                        tr('Delete group'),
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(tr('This group has ended. Remove it from your chats.')),
                      onTap: () => ChatActions.deleteChat(context, chat.id, cubit.me.id),
                    ),
                  ),
                ),
              if (amIMember && !chat.closed)
                SliverToBoxAdapter(
                  child: _Card(
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                      title: Text(
                        cubit.isOwner ? tr('Exit and end group') : tr('Exit group'),
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                      subtitle:
                          cubit.isOwner ? Text(tr('You created this group — leaving ends it for everyone')) : null,
                      onTap: () async {
                        final ok = await AppFeedback.confirm(
                          context,
                          title: cubit.isOwner ? tr('End "{0}"?', [chat.name]) : tr('Exit "{0}"?', [chat.name]),
                          message:
                              cubit.isOwner
                                  ? tr(
                                    'You are the group owner. Leaving ends the group for everyone — nobody can send messages in it anymore.',
                                  )
                                  : chat.secret
                                  ? tr('This is a secret group: you will need an admin to invite you back.')
                                  : tr('You can rejoin later from the chat, unless the group becomes secret.'),
                          confirmLabel: cubit.isOwner ? tr('End group') : tr('Exit'),
                          destructive: true,
                        );
                        if (ok) await cubit.leave();
                      },
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(20)),
    child: child,
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (r) => AppColors.brandGradient.createShader(r),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 6),
                Text(label, style: context.text.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
