import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/usecases/chat_extras.dart';
import '../bloc/group/group_info_cubit.dart';

/// Shows how I appear in the group and lets me reveal / hide my identity.
class GroupIdentityCard extends StatelessWidget {
  const GroupIdentityCard({super.key, required this.cubit, required this.chat});
  final GroupInfoCubit cubit;
  final ChatEntity chat;

  @override
  Widget build(BuildContext context) {
    final myId = cubit.me.id;
    final alias = chat.aliasOf(myId);
    final hideAgainAt = chat.canHideAgainAt(myId);
    final secondary = TextStyle(color: context.palette.textSecondary, fontSize: 13, height: 1.35);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alias != null ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alias != null ? 'You appear as "$alias"' : 'You appear as ${cubit.me.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (alias != null)
            Text(
              "Members can't see your name, photo or number. If you reveal your identity, "
              "you can't become anonymous again for 24 hours.",
              style: secondary,
            )
          else if (hideAgainAt != null)
            Text(
              'You revealed your identity recently. You can become anonymous again '
              '${GroupMembership.formatUntil(hideAgainAt)}.',
              style: secondary,
            )
          else
            Text("You can hide your name and photo from this group's members.", style: secondary),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child:
                alias != null
                    ? FilledButton.icon(
                      onPressed: () async {
                        final ok = await AppFeedback.confirm(
                          context,
                          title: 'Reveal your identity?',
                          message:
                              'Everyone in "${chat.name}" will see that "$alias" is ${cubit.me.name}. '
                              'After this you must wait 24 hours before you can be anonymous again.',
                          confirmLabel: 'Reveal',
                        );
                        if (ok) await cubit.revealIdentity();
                      },
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Reveal identity'),
                    )
                    : OutlinedButton.icon(
                      onPressed:
                          hideAgainAt != null
                              ? null
                              : () async {
                                final ok = await AppFeedback.confirm(
                                  context,
                                  title: 'Become anonymous?',
                                  message:
                                      'Members will see a nickname instead of your name and photo, '
                                      'including on messages you already sent.',
                                  confirmLabel: 'Go anonymous',
                                );
                                if (ok) await cubit.hideIdentity();
                              },
                      icon: const Icon(Icons.visibility_off_rounded),
                      label: Text(
                        hideAgainAt != null ? 'Available ${GroupMembership.formatUntil(hideAgainAt)}' : 'Go anonymous',
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

/// Create / copy / share / reset / turn off the group's join link.
Future<void> showInviteLinkSheet(BuildContext context, GroupInfoCubit cubit) async {
  var code = await cubit.ensureInviteCode();
  if (code == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder: (ctx, setState) {
            final link = GroupLinks.build(cubit.chatId, code!);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite via link', style: ctx.text.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Anyone with this link can join the group. Only share it with people you trust.',
                      style: TextStyle(color: ctx.palette.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ctx.palette.surfaceHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(link, style: const TextStyle(color: AppColors.primary)),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.share_rounded),
                      title: const Text('Share link'),
                      onTap:
                          () => SharePlus.instance.share(
                            ShareParams(text: 'Join my group on BCC Chat: $link', subject: 'Group invite'),
                          ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.copy_rounded),
                      title: const Text('Copy link'),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (ctx.mounted) AppFeedback.info(ctx, 'Link copied');
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('Reset link'),
                      subtitle: const Text('The old link will stop working'),
                      onTap: () async {
                        final next = await cubit.ensureInviteCode(reset: true);
                        if (next != null) setState(() => code = next);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link_off_rounded, color: AppColors.danger),
                      title: const Text('Turn off link', style: TextStyle(color: AppColors.danger)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await cubit.revokeLink();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}
