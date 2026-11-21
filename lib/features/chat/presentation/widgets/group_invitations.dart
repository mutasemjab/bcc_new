import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../users/domain/entities/user_entity.dart';
import '../../../users/domain/usecases/user_usecases.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/usecases/chat_extras.dart';
import 'join_identity_sheet.dart';

/// Shows a group invitation the user can accept (as themselves or
/// anonymously) or decline. Used by the chat list and the join-link page.
Future<bool> acceptGroupInvite(BuildContext context, {required String chatId, required String groupName}) async {
  final session = context.read<SessionBloc>().state;
  if (session is! SessionAuthenticated) return false;
  final me = session.user;
  final choice = await showJoinIdentitySheet(context, groupName: groupName, myName: me.name, myPhotoUrl: me.photoUrl);
  if (choice == null) return false;
  final alias = choice == JoinIdentity.anonymous ? IdUtils.anonymousAlias() : null;
  final r = await sl<GroupMembership>().accept(chatId, me.id, me.name, alias: alias);
  if (!context.mounted) return false;
  return r.fold(
    (f) {
      AppFeedback.error(context, f.message);
      return false;
    },
    (_) {
      if (alias != null) AppFeedback.info(context, 'You joined as $alias');
      return true;
    },
  );
}

/// Pending group invitations, shown above the chat list.
class GroupInvitationsSection extends StatefulWidget {
  const GroupInvitationsSection({super.key, required this.uid});
  final String uid;

  @override
  State<GroupInvitationsSection> createState() => _GroupInvitationsSectionState();
}

class _GroupInvitationsSectionState extends State<GroupInvitationsSection> {
  StreamSubscription<List<ChatEntity>>? _sub;
  StreamSubscription<Map<String, UserEntity>>? _usersSub;
  List<ChatEntity> _invites = const [];
  Map<String, UserEntity> _inviters = const {};
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _sub = sl<GroupMembership>().invitations(widget.uid).listen((list) {
      if (!mounted) return;
      setState(() => _invites = list);
      final ids = {for (final c in list) c.invitedBy[widget.uid] ?? c.createdBy ?? ''}..remove('');
      _usersSub?.cancel();
      _usersSub = sl<WatchUsers>()(ids).listen((u) {
        if (mounted) setState(() => _inviters = u);
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _usersSub?.cancel();
    super.dispose();
  }

  Future<void> _accept(ChatEntity chat) async {
    setState(() => _busy.add(chat.id));
    final ok = await acceptGroupInvite(context, chatId: chat.id, groupName: chat.name ?? 'Group');
    if (!mounted) return;
    setState(() => _busy.remove(chat.id));
    if (ok) context.push(AppRoutes.conversation(chat.id));
  }

  Future<void> _decline(ChatEntity chat) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Decline invitation?',
      message: 'You won\'t join "${chat.name ?? 'this group'}". An admin can invite you again later.',
      confirmLabel: 'Decline',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy.add(chat.id));
    final r = await sl<GroupMembership>().decline(chat.id, widget.uid);
    if (!mounted) return;
    setState(() => _busy.remove(chat.id));
    r.match((f) => AppFeedback.error(context, f.message), (_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_invites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Text(
            'GROUP INVITATIONS',
            style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
        ),
        for (final chat in _invites)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: context.palette.surfaceHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AppAvatar(name: chat.name ?? 'Group', imageUrl: chat.photoUrl, size: 48, isGroup: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(chat.name ?? 'Group', style: context.text.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            '${_inviterName(chat)} invited you • ${chat.participants.length} members',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy.contains(chat.id) ? null : () => _decline(chat),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy.contains(chat.id) ? null : () => _accept(chat),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _inviterName(ChatEntity chat) {
    final id = chat.invitedBy[widget.uid] ?? chat.createdBy;
    if (id == null) return 'Someone';
    return chat.aliasOf(id) ?? _inviters[id]?.name ?? 'Someone';
  }
}
