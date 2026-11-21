import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../domain/entities/user_entity.dart';

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user, this.onTap, this.trailing, this.subtitle, this.title});
  final UserEntity user;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  /// Overrides the profile name (e.g. the name saved in the phone book).
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: AppAvatar(name: user.name, imageUrl: user.photoUrl, size: 48, isOnline: user.isOnline),
      title: Text(title ?? user.name, style: context.text.titleMedium),
      subtitle: Text(
        subtitle ?? user.about,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.palette.textSecondary),
      ),
      trailing: trailing,
    );
  }
}
