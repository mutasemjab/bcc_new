import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../widgets/auth_background.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 3),
                _Staggered(index: 0, child: const BrandLogo(size: 96)),
                const SizedBox(height: 36),
                _Staggered(
                  index: 1,
                  child: Text(
                    'Talk freely.\nConnect instantly.',
                    textAlign: TextAlign.center,
                    style: context.text.displaySmall?.copyWith(fontSize: 34, height: 1.15),
                  ),
                ),
                const SizedBox(height: 16),
                _Staggered(
                  index: 2,
                  child: Text(
                    'Messages, voice notes, stories, groups and crystal-clear\nvoice & video calls — all in real time.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(color: context.palette.textSecondary),
                  ),
                ),
                const Spacer(flex: 4),
                _Staggered(
                  index: 3,
                  child: GradientButton(
                    label: 'Continue with phone',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => context.push(AppRoutes.phoneAuth),
                  ),
                ),
                const SizedBox(height: 14),
                _Staggered(
                  index: 4,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.emailAuth),
                    icon: const Icon(Icons.alternate_email_rounded),
                    label: const Text('Continue with email'),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Real-time messaging • Private & secure', style: context.text.labelSmall),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 120),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: c)),
      child: child,
    );
  }
}
