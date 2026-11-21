import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/pressable.dart';
import '../features/calls/presentation/bloc/call_log/call_log_cubit.dart';
import '../features/calls/presentation/pages/calls_page.dart';
import '../features/chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../features/chat/presentation/pages/chats_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/status/presentation/pages/status_page.dart';
import 'routes.dart';

/// Main tabs with a floating, frosted bottom navigation bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [ChatsPage(), StatusPage(), CallsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    final unread = context.select((ChatListBloc b) => b.state.totalUnread);
    final missed = context.select((CallLogCubit c) {
      final s = c.state;
      final since = DateTime.now().subtract(const Duration(days: 1));
      return s.calls.where((call) => s.isMissed(call) && (call.createdAt?.isAfter(since) ?? false)).length;
    });

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: AnimatedScale(
        scale: _index == 0 ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 84),
          child: Pressable(
            onTap: () => context.push(AppRoutes.newChat),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _FloatingNavBar(
        index: _index,
        onChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        items: [
          _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats', badge: unread),
          const _NavItem(Icons.amp_stories_outlined, Icons.amp_stories_rounded, 'Stories'),
          _NavItem(Icons.call_outlined, Icons.call_rounded, 'Calls', badge: missed),
          const _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.index, required this.onChanged, required this.items});
  final int index;
  final ValueChanged<int> onChanged;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: context.isDark ? 0.72 : 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.palette.stroke.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(child: _NavButton(item: items[i], selected: i == index, onTap: () => onChanged(i))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = context.palette.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient:
                      selected
                          ? LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.22),
                              AppColors.accent.withValues(alpha: 0.22),
                            ],
                          )
                          : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    selected
                        ? ShaderMask(
                          shaderCallback: (r) => AppColors.brandGradient.createShader(r),
                          child: Icon(item.activeIcon, color: Colors.white, size: 24),
                        )
                        : Icon(item.icon, color: inactive, size: 24),
              ),
              if (item.badge > 0)
                Positioned(
                  right: selected ? 6 : 0,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: context.colors.surface, width: 1.5),
                    ),
                    child: Text(
                      item.badge > 99 ? '99+' : '${item.badge}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? context.colors.primary : inactive,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
