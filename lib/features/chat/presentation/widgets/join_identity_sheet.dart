import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/pressable.dart';

enum JoinIdentity { me, anonymous }

/// Asked when joining a group: show my profile, or join anonymously.
Future<JoinIdentity?> showJoinIdentitySheet(
  BuildContext context, {
  required String groupName,
  required String myName,
  String? myPhotoUrl,
}) {
  return showModalBottomSheet<JoinIdentity>(
    context: context,
    isScrollControlled: true,
    builder:
        (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join "$groupName"', style: ctx.text.titleLarge),
                const SizedBox(height: 4),
                Text('How do you want to appear to the members?', style: TextStyle(color: ctx.palette.textSecondary)),
                const SizedBox(height: 16),
                _Option(
                  leading: AppAvatar(name: myName, imageUrl: myPhotoUrl, size: 46),
                  title: 'Join as $myName',
                  body: 'Members see your name, photo and profile.',
                  onTap: () => Navigator.pop(ctx, JoinIdentity.me),
                ),
                const SizedBox(height: 10),
                _Option(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ctx.palette.surfaceHigh),
                    child: Icon(Icons.visibility_off_rounded, color: ctx.palette.textSecondary),
                  ),
                  title: 'Join anonymously',
                  body:
                      'Members see a nickname like "Member #4821" — no name or photo. '
                      'You can reveal yourself later from Group info, but after revealing you '
                      'must wait 24 hours before you can hide again.',
                  onTap: () => Navigator.pop(ctx, JoinIdentity.anonymous),
                ),
              ],
            ),
          ),
        ),
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.leading, required this.title, required this.body, required this.onTap});
  final Widget leading;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: context.palette.textSecondary, height: 1.35, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}
