import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../users/domain/entities/user_entity.dart';
import '../../../users/domain/usecases/user_usecases.dart';
import '../../../users/presentation/block_list.dart';
import '../../../users/presentation/widgets/user_tile.dart';

/// Privacy: last seen, online, read receipts, blocked contacts.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Future<void> _update(
    BuildContext context,
    String uid, {
    bool? hideLastSeen,
    bool? hideOnline,
    bool? readReceipts,
  }) async {
    final r = await sl<PrivacySettings>().update(
      uid,
      hideLastSeen: hideLastSeen,
      hideOnline: hideOnline,
      readReceipts: readReceipts,
    );
    if (context.mounted) r.match((f) => AppFeedback.error(context, f.message), (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, session) {
        if (session is! SessionAuthenticated) return const Scaffold();
        final me = session.user;
        final secondary = TextStyle(color: context.palette.textSecondary, fontSize: 13, height: 1.35);
        return Scaffold(
          appBar: AppBar(title: const Text('Privacy')),
          body: ListView(
            children: [
              const _Header('Who can see my personal info'),
              SwitchListTile(
                value: !me.hideLastSeen,
                onChanged: (v) => _update(context, me.id, hideLastSeen: !v),
                activeThumbColor: AppColors.primary,
                title: const Text('Last seen'),
                subtitle: Text(me.hideLastSeen ? 'Nobody' : 'Everyone', style: secondary),
              ),
              SwitchListTile(
                value: !me.hideOnline,
                onChanged: (v) => _update(context, me.id, hideOnline: !v),
                activeThumbColor: AppColors.primary,
                title: const Text('Online'),
                subtitle: Text(me.hideOnline ? 'Nobody' : 'Everyone', style: secondary),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  "If you don't share your last seen or online status, you won't be able to see other "
                  "people's last seen or online status.",
                  style: secondary,
                ),
              ),
              const Divider(),
              SwitchListTile(
                value: me.readReceipts,
                onChanged: (v) => _update(context, me.id, readReceipts: v),
                activeThumbColor: AppColors.primary,
                title: const Text('Read receipts'),
                subtitle: Text(
                  "If turned off, you won't send or receive read receipts (blue ticks) in individual chats. "
                  'Read receipts are always sent for group chats.',
                  style: secondary,
                ),
              ),
              const Divider(),
              ListenableBuilder(
                listenable: sl<BlockList>(),
                builder:
                    (context, _) => ListTile(
                      leading: const Icon(Icons.block_rounded, color: AppColors.danger),
                      title: const Text('Blocked contacts'),
                      subtitle: Text('${sl<BlockList>().blocked.length}', style: secondary),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap:
                          () => Navigator.of(
                            context,
                          ).push(MaterialPageRoute<void>(builder: (_) => const BlockedContactsPage())),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BlockedContactsPage extends StatelessWidget {
  const BlockedContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = sl<BlockList>();
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked contacts')),
      body: ListenableBuilder(
        listenable: list,
        builder: (context, _) {
          if (list.blocked.isEmpty) {
            return const EmptyState(
              icon: Icons.block_rounded,
              title: 'No blocked contacts',
              message: "Blocked contacts can't call you or send you messages.",
            );
          }
          return StreamBuilder<Map<String, UserEntity>>(
            stream: sl<WatchUsers>()(list.blocked),
            builder: (context, snap) {
              final users = snap.data ?? const <String, UserEntity>{};
              return ListView(
                children: [
                  for (final id in list.blocked)
                    UserTile(
                      user: users[id] ?? UserEntity(id: id, name: 'Unknown'),
                      subtitle: 'Blocked',
                      trailing: TextButton(
                        onPressed: () async {
                          final err = await list.unblock(id);
                          if (context.mounted) AppFeedback.info(context, err ?? 'Unblocked');
                        },
                        child: const Text('Unblock'),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
    ),
  );
}
