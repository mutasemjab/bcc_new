import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/id_utils.dart';
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

/// Full "how do you want to join?" flow. Returns null if cancelled;
/// `alias` is null when joining with the real name & number, otherwise the
/// secret name the user chose.
Future<({String? alias})?> chooseJoinIdentity(
  BuildContext context, {
  required String groupName,
  required String myName,
  String? myPhotoUrl,
}) async {
  final choice = await showJoinIdentitySheet(context, groupName: groupName, myName: myName, myPhotoUrl: myPhotoUrl);
  if (choice == null || !context.mounted) return null;
  if (choice == JoinIdentity.me) return (alias: null);
  final alias = await askSecretName(context, realName: myName);
  return alias == null ? null : (alias: alias);
}

/// Lets the user type their secret name (pre-filled with a random one).
Future<String?> askSecretName(BuildContext context, {required String realName}) async {
  final controller = TextEditingController(text: IdUtils.anonymousAlias());
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setState) => AlertDialog(
                title: const Text('Your secret name'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Members will see this name instead of your real name and number.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 30,
                      decoration: InputDecoration(errorText: error, counterText: ''),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      final v = controller.text.trim();
                      if (v.length < 2) {
                        setState(() => error = 'At least 2 characters');
                      } else if (v.toLowerCase() == realName.trim().toLowerCase()) {
                        setState(() => error = "Don't use your real name");
                      } else {
                        Navigator.pop(ctx, v);
                      }
                    },
                    child: const Text('Join'),
                  ),
                ],
              ),
        ),
  );
  controller.dispose();
  return result;
}
