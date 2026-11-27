import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../calls/domain/entities/call_entity.dart';
import '../../../calls/presentation/call_launcher.dart';
import '../../../chat/domain/entities/chat_entity.dart';
import '../../../chat/presentation/chat_actions.dart';
import '../../../chat/presentation/pages/media_viewer_page.dart';
import '../block_list.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/user_usecases.dart';
import '../bloc/user_profile/user_profile_cubit.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserProfileCubit(sl<WatchUser>(), uid),
      child: BlocBuilder<UserProfileCubit, UserEntity?>(
        builder: (context, user) {
          final session = context.read<SessionBloc>().state;
          if (user == null || session is! SessionAuthenticated) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final me = session.user.id;
          final chatId = IdUtils.directChatId(me, user.id);
          final directChat = ChatEntity(id: chatId, isGroup: false, participants: [me, user.id]);

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 64, 20, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary.withValues(alpha: 0.35), context.theme.scaffoldBackgroundColor],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tap → full-size photo.
                      GestureDetector(
                        onTap:
                            user.photoUrl == null
                                ? null
                                : () => MediaViewerPage.open(context, url: user.photoUrl!, heroTag: 'photo-$chatId'),
                        child: Hero(
                          tag: 'photo-$chatId',
                          child: AppAvatar(name: user.name, imageUrl: user.photoUrl, size: 130),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(user.name, style: context.text.headlineSmall),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          // Privacy works both ways (WhatsApp): hide mine → can't see theirs.
                          final online =
                              user.isOnline && !session.user.hideOnline && !sl<BlockList>().isBlocked(user.id);
                          final seen =
                              session.user.hideLastSeen || user.lastSeen == null || sl<BlockList>().isBlocked(user.id)
                                  ? ''
                                  : Formatters.lastSeen(user.lastSeen);
                          return Text(
                            online ? tr('online') : seen,
                            style: TextStyle(color: online ? AppColors.online : context.palette.textSecondary),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _Action(
                        icon: Icons.chat_bubble_rounded,
                        label: tr('Message'),
                        onTap: () => context.push(AppRoutes.conversation(chatId)),
                      ),
                      const SizedBox(width: 12),
                      _Action(
                        icon: Icons.call_rounded,
                        label: tr('Voice'),
                        onTap:
                            () => CallLauncher.start(
                              context,
                              chat: directChat,
                              users: {user.id: user},
                              type: CallType.voice,
                            ),
                      ),
                      const SizedBox(width: 12),
                      _Action(
                        icon: Icons.videocam_rounded,
                        label: tr('Video'),
                        onTap:
                            () => CallLauncher.start(
                              context,
                              chat: directChat,
                              users: {user.id: user},
                              type: CallType.video,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  children: [
                    _InfoRow(icon: Icons.info_outline_rounded, label: tr('About'), value: user.about),
                    if (user.phone != null) _InfoRow(icon: Icons.phone_rounded, label: tr('Phone'), value: user.phone!),
                    if (user.email != null)
                      _InfoRow(icon: Icons.alternate_email_rounded, label: tr('Email'), value: user.email!),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.perm_media_rounded, color: AppColors.primary),
                      title: Text(tr('Media, links and docs')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.chatMedia(chatId)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary),
                      title: Text(tr('Clear chat')),
                      onTap: () => ChatActions.clearChat(context, chatId, me),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wallpaper_rounded, color: AppColors.primary),
                      title: Text(tr('Chat wallpaper')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(tr('{0}?chatId={1}', [AppRoutes.wallpaper, chatId])),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  children: [
                    ListenableBuilder(
                      listenable: sl<BlockList>(),
                      builder: (context, _) {
                        final blocked = sl<BlockList>().isBlocked(user.id);
                        return ListTile(
                          leading: Icon(
                            blocked ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                            color: AppColors.danger,
                          ),
                          title: Text(
                            blocked ? tr('Unblock {0}', [user.name]) : tr('Block {0}', [user.name]),
                            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                          onTap: () => ChatActions.toggleBlock(context, user.id, user.name),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      title: Text(
                        tr('Delete chat'),
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                      onTap: () => ChatActions.deleteChat(context, chatId, me),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
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
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(20)),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(value),
    subtitle: Text(label, style: TextStyle(color: context.palette.textSecondary)),
  );
}
