import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/segmented_ring.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../../../users/domain/entities/user_entity.dart';
import '../../domain/entities/status_entity.dart';
import '../bloc/status_bloc.dart';
import 'status_editor_pages.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  Future<void> _addImage(BuildContext context) async {
    final file = await sl<MediaPickerService>().pickImage();
    if (file == null || !context.mounted) return;
    // Opened directly (not via the router) so the picked photo can't get lost
    // when the app resumes from the gallery.
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ImageStatusEditorPage(image: file)));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    if (session is! SessionAuthenticated) return const SizedBox.shrink();
    final me = session.user;
    final users = context.select((ChatListBloc b) => b.state.users);

    return BlocBuilder<StatusBloc, StatusState>(
      builder: (context, state) {
        final mine = state.mine;
        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 108,
                  backgroundColor: context.theme.scaffoldBackgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                    title: Text(
                      tr('Stories'),
                      style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MyStatusTile(
                    name: me.name,
                    photoUrl: me.photoUrl,
                    mine: mine,
                    posting: state.posting,
                    onTap: () => mine == null ? _addImage(context) : context.push(AppRoutes.statusViewer(me.id)),
                  ),
                ),
                if (state.recent.isEmpty && state.viewed.isEmpty && !state.loading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.auto_awesome_rounded,
                      title: tr('No stories yet'),
                      message: tr('Stories from people you chat with appear here for 24 hours.'),
                    ),
                  ),
                if (state.recent.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _Header(tr('Recent updates'))),
                  SliverList.builder(
                    itemCount: state.recent.length,
                    itemBuilder: (_, i) => _StatusTile(group: state.recent[i], me: me.id, users: users),
                  ),
                ],
                if (state.viewed.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _Header(tr('Viewed'))),
                  SliverList.builder(
                    itemCount: state.viewed.length,
                    itemBuilder: (_, i) => _StatusTile(group: state.viewed[i], me: me.id, users: users),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 160)),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 112,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'status-text',
                    backgroundColor: context.palette.surfaceHigh,
                    foregroundColor: context.colors.onSurface,
                    onPressed: () => context.push(AppRoutes.statusText),
                    child: const Icon(Icons.edit_rounded),
                  ),
                  const SizedBox(height: 12),
                  Pressable(
                    onTap: () => _addImage(context),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyStatusTile extends StatelessWidget {
  const _MyStatusTile({required this.name, this.photoUrl, this.mine, required this.posting, required this.onTap});
  final String name;
  final String? photoUrl;
  final UserStatuses? mine;
  final bool posting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = mine?.statuses.length ?? 0;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: SizedBox(
        width: 62,
        height: 62,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (count > 0)
              SegmentedRing(
                segments: count,
                seenSegments: 0,
                size: 62,
                child: AppAvatar(name: name, imageUrl: photoUrl, size: 52),
              )
            else
              Padding(padding: const EdgeInsets.all(5), child: AppAvatar(name: name, imageUrl: photoUrl, size: 52)),
            if (count == 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.theme.scaffoldBackgroundColor, width: 2),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                ),
              ),
            if (posting) const Positioned.fill(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
      title: Text(tr('My story'), style: context.text.titleMedium),
      subtitle: Text(
        posting
            ? tr('Sharing…')
            : count == 0
            ? tr('Tap to add a story')
            : tr('{0} update{1} • {2}', [count, count == 1 ? '' : 's', Formatters.relative(mine!.latest)]),
        style: TextStyle(color: context.palette.textSecondary),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.group, required this.me, required this.users});
  final UserStatuses group;
  final String me;
  final Map<String, UserEntity> users;

  @override
  Widget build(BuildContext context) {
    final name = users[group.userId]?.name ?? '…';
    final last = group.statuses.last;
    return ListTile(
      onTap: () => context.push(AppRoutes.statusViewer(group.userId)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: SegmentedRing(
        segments: group.statuses.length,
        seenSegments: group.seenCount(me),
        size: 62,
        child:
            last.type == StatusType.image && last.mediaUrl != null
                ? CircleAvatar(radius: 26, backgroundImage: CachedNetworkImageProvider(last.mediaUrl!))
                : Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(last.backgroundColor)),
                  child: Text(
                    last.text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w700),
                  ),
                ),
      ),
      title: Text(name, style: context.text.titleMedium),
      subtitle: Text(Formatters.relative(group.latest), style: TextStyle(color: context.palette.textSecondary)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
    child: Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
    ),
  );
}
