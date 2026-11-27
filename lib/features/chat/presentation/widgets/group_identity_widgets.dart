import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/usecases/chat_extras.dart';
import '../bloc/group/group_info_cubit.dart';
import 'join_identity_sheet.dart';

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
    final isAdmin = chat.isAdmin(myId);
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
                  alias != null ? tr('You appear as "{0}"', [alias]) : tr('You appear as {0}', [cubit.me.name]),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (alias != null)
            Text(
              tr(
                'Members can\'t see your name, photo or number. If you reveal your identity, you can\'t become anonymous again for 24 hours.',
              ),
              style: secondary,
            )
          else if (hideAgainAt != null)
            Text(
              tr('You revealed your identity recently. You can become anonymous again {0}.', [
                GroupMembership.formatUntil(hideAgainAt),
              ]),
              style: secondary,
            )
          else if (isAdmin)
            Text(tr('Admins are always shown with their real name to all members.'), style: secondary)
          else
            Text(tr('You can hide your name and photo from this group\'s members.'), style: secondary),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child:
                alias != null
                    ? FilledButton.icon(
                      onPressed: () async {
                        final ok = await AppFeedback.confirm(
                          context,
                          title: tr('Reveal your identity?'),
                          message: tr(
                            'Everyone in "{0}" will see that "{1}" is {2}. After this you must wait 24 hours before you can be anonymous again.',
                            [chat.name, alias, cubit.me.name],
                          ),
                          confirmLabel: tr('Reveal'),
                        );
                        if (ok) await cubit.revealIdentity();
                      },
                      icon: const Icon(Icons.visibility_rounded),
                      label: Text(tr('Reveal identity')),
                    )
                    : OutlinedButton.icon(
                      onPressed:
                          hideAgainAt != null || isAdmin
                              ? null
                              : () async {
                                final ok = await AppFeedback.confirm(
                                  context,
                                  title: tr('Become anonymous?'),
                                  message: tr(
                                    'Members will see a nickname instead of your name and photo, including on messages you already sent.',
                                  ),
                                  confirmLabel: tr('Go anonymous'),
                                );
                                if (!ok || !context.mounted) return;
                                final alias = await askSecretName(context, realName: cubit.me.name);
                                if (alias != null) await cubit.hideIdentity(alias: alias);
                              },
                      icon: const Icon(Icons.visibility_off_rounded),
                      label: Text(
                        hideAgainAt != null
                            ? tr('Available {0}', [GroupMembership.formatUntil(hideAgainAt)])
                            : tr('Go anonymous'),
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
                    Text(tr('Invite via link'), style: ctx.text.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      tr('Anyone with this link can join the group. Only share it with people you trust.'),
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
                      title: Text(tr('Share link')),
                      onTap:
                          () => SharePlus.instance.share(
                            ShareParams(text: tr('Join my group on BCC Chat: {0}', [link]), subject: 'Group invite'),
                          ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.copy_rounded),
                      title: Text(tr('Copy link')),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (ctx.mounted) AppFeedback.info(ctx, tr('Link copied'));
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh_rounded),
                      title: Text(tr('Reset link')),
                      subtitle: Text(tr('The old link will stop working')),
                      onTap: () async {
                        final next = await cubit.ensureInviteCode(reset: true);
                        if (next != null) setState(() => code = next);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link_off_rounded, color: AppColors.danger),
                      title: Text(tr('Turn off link'), style: TextStyle(color: AppColors.danger)),
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
