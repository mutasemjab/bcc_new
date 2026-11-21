import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../users/presentation/pages/link_phone_page.dart';
import '../../../appointments/appointments.dart';
import '../../../chat/presentation/starred.dart';
import 'font_page.dart';
import 'privacy_page.dart';
import 'support_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    if (session is! SessionAuthenticated) return const SizedBox.shrink();
    final user = session.user;
    final mode = context.watch<ThemeCubit>().state;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 108,
          backgroundColor: context.theme.scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
            title: Text('Settings', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ),
        SliverToBoxAdapter(
          child: Pressable(
            onTap: () => context.push(AppRoutes.editProfile),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.9), AppColors.accent.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: AppAvatar(name: user.name, imageUrl: user.photoUrl, size: 64),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.about,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        _section(context, 'Appearance', [
          Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                side: BorderSide(color: context.palette.stroke),
              ),
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('System'),
                ),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => context.read<ThemeCubit>().setMode(s.first),
            ),
          ),
        ]),
        _section(context, 'Account', [
          _tile(
            context,
            Icons.phone_rounded,
            'Phone',
            subtitle: user.phone ?? 'Add your number so friends can find you',
            color: AppColors.online,
            onTap:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => LinkPhonePage(current: user.phone))),
          ),
          if (user.email != null)
            _tile(context, Icons.alternate_email_rounded, 'Email', subtitle: user.email, color: AppColors.primary),
          _tile(
            context,
            Icons.person_rounded,
            'Edit profile',
            color: AppColors.violet,
            onTap: () => context.push(AppRoutes.editProfile),
          ),
        ]),
        _section(context, 'Chats', [
          _tile(
            context,
            Icons.wallpaper_rounded,
            'Chat wallpaper',
            subtitle: 'Default background for all chats',
            color: AppColors.primary,
            onTap: () => context.push(AppRoutes.wallpaper),
          ),
          _tile(
            context,
            Icons.font_download_rounded,
            'Font',
            subtitle: 'Font style and text size',
            color: AppColors.primary,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FontPage())),
          ),
          _tile(
            context,
            Icons.star_rounded,
            'Starred messages',
            color: AppColors.warning,
            onTap:
                () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StarredMessagesPage())),
          ),
          _tile(
            context,
            Icons.event_note_rounded,
            'Appointments',
            subtitle: 'Saved appointments and reminders',
            color: AppColors.online,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AppointmentsPage())),
          ),
        ]),
        _section(context, 'Help', [
          _tile(
            context,
            Icons.support_agent_rounded,
            'Help & support',
            subtitle: 'Contact us • Company info',
            color: AppColors.primary,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SupportPage())),
          ),
        ]),
        _section(context, 'Privacy & security', [
          _tile(
            context,
            Icons.lock_rounded,
            'Privacy',
            subtitle: 'Last seen, online, read receipts, blocked contacts',
            color: AppColors.primary,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPage())),
          ),
          _tile(
            context,
            Icons.shield_rounded,
            'Private & secure',
            subtitle: 'Only the members of a chat can read its messages.',
            color: AppColors.accent,
          ),
        ]),
        _section(context, '', [
          _tile(
            context,
            Icons.logout_rounded,
            'Sign out',
            color: AppColors.danger,
            danger: true,
            onTap: () async {
              final ok = await AppFeedback.confirm(
                context,
                title: 'Sign out?',
                message: 'You can sign back in any time.',
                confirmLabel: 'Sign out',
                destructive: true,
              );
              if (ok && context.mounted) context.read<SessionBloc>().add(const SessionSignOutRequested());
            },
          ),
        ]),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 140),
            child: Column(
              children: [
                const BrandLogo(size: 40),
                const SizedBox(height: 10),
                Text('BCC Chat • v1.0.0', style: context.text.labelSmall),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) => SliverToBoxAdapter(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
            child: Text(
              title.toUpperCase(),
              style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(children: children),
        ),
      ],
    ),
  );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    required Color color,
    VoidCallback? onTap,
    bool danger = false,
  }) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? AppColors.danger : null)),
    subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: context.palette.textSecondary)),
    trailing: onTap == null || danger ? null : const Icon(Icons.chevron_right_rounded),
  );
}
