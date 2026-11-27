import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../users/domain/entities/user_entity.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/message_entity.dart';
import 'typing_indicator.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.myId,
    required this.title,
    required this.photoUrl,
    required this.peer,
    required this.users,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatEntity chat;
  final String myId;
  final String title;
  final String? photoUrl;
  final UserEntity? peer;
  final Map<String, UserEntity> users;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unread = chat.unreadFor(myId);
    final muted = chat.isMutedFor(myId);
    final typing = chat.typingUsers(myId);
    final last = chat.lastMessage;
    final hasUnread = unread > 0;

    Widget subtitle;
    if (typing.isNotEmpty) {
      final who =
          chat.isGroup
              ? tr('{0} is typing', [
                chat.aliasOf(typing.first) ?? users[typing.first]?.name.split(' ').first ?? 'Someone',
              ])
              : tr('typing');
      subtitle = TypingLabel(text: who, color: AppColors.accent);
    } else if (last != null && !chat.isClearedFor(myId)) {
      final mine = last.senderId == myId;
      final prefix =
          last.type == MessageType.system
              ? ''
              : mine
              ? tr('You: ')
              : chat.isGroup
              ? '${chat.aliasOf(last.senderId) ?? users[last.senderId]?.name.split(' ').first ?? ''}: '
              : '';
      subtitle = Row(
        children: [
          Expanded(
            child: Text(
              '$prefix${last.preview}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread ? context.colors.onSurface : palette.textSecondary,
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    } else {
      subtitle = Text(
        chat.isGroup ? tr('Group created') : '',
        style: TextStyle(color: palette.textSecondary, fontSize: 14),
      );
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            AppAvatar(
              name: title,
              imageUrl: photoUrl,
              size: 56,
              isGroup: chat.isGroup,
              isOnline: peer?.isOnline ?? false,
              heroTag: 'avatar-${chat.id}',
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(fontSize: 16.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.chatListTime(last?.createdAt ?? chat.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? AppColors.primary : palette.textSecondary,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: subtitle),
                      if (muted) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.volume_off_rounded, size: 17, color: palette.textSecondary),
                      ],
                      if (chat.isPinnedFor(myId)) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin_rounded, size: 16, color: palette.textSecondary),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child:
                            hasUnread
                                ? Container(
                                  key: ValueKey(unread),
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 7),
                                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: muted ? null : AppColors.brandGradient,
                                    color: muted ? palette.textSecondary : null,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
