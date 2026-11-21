import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/bloc/session/session_bloc.dart';
import '../features/auth/presentation/pages/email_auth_page.dart';
import '../features/auth/presentation/pages/phone_auth_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/calls/domain/entities/call_entity.dart';
import '../features/calls/presentation/call_launcher.dart';
import '../features/calls/presentation/pages/call_page.dart';
import '../features/calls/presentation/pages/incoming_call_page.dart';
import '../features/chat/presentation/pages/chat_media_page.dart';
import '../features/chat/presentation/pages/conversation_page.dart';
import '../features/chat/presentation/pages/create_group_page.dart';
import '../features/chat/presentation/pages/group_info_page.dart';
import '../features/chat/presentation/pages/join_group_page.dart';
import '../features/chat/presentation/pages/new_chat_page.dart';
import '../features/settings/presentation/pages/wallpaper_page.dart';
import '../features/status/presentation/pages/status_editor_pages.dart';
import '../features/status/presentation/pages/status_viewer_page.dart';
import '../features/users/presentation/pages/profile_setup_page.dart';
import '../features/users/presentation/pages/user_profile_page.dart';
import 'home_shell.dart';
import 'routes.dart';
import 'splash_page.dart';

/// Builds the router. Auth-driven redirects come from [SessionBloc].
GoRouter buildRouter(SessionBloc session) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _StreamListenable(session.stream),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final s = session.state;
      final onAuth = loc.startsWith(AppRoutes.welcome);
      switch (s) {
        case SessionUnknown():
          return loc == AppRoutes.splash ? null : AppRoutes.splash;
        case SessionUnauthenticated():
          return onAuth ? null : AppRoutes.welcome;
        case SessionNeedsProfile():
          return loc == AppRoutes.profileSetup ? null : AppRoutes.profileSetup;
        case SessionAuthenticated():
          if (onAuth || loc == AppRoutes.splash || loc == AppRoutes.profileSetup) return AppRoutes.home;
          return null;
      }
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, __) => const WelcomePage(),
        routes: [
          GoRoute(path: 'email', builder: (_, __) => const EmailAuthPage()),
          GoRoute(path: 'phone', builder: (_, __) => const PhoneAuthPage()),
        ],
      ),
      GoRoute(path: AppRoutes.profileSetup, builder: (_, __) => const ProfileSetupPage()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeShell()),
      GoRoute(path: AppRoutes.newChat, builder: (_, __) => const NewChatPage()),
      GoRoute(path: AppRoutes.newGroup, builder: (_, __) => const CreateGroupPage()),
      GoRoute(path: AppRoutes.editProfile, builder: (_, __) => const ProfileSetupPage(isEditing: true)),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, s) => ConversationPage(chatId: s.pathParameters['chatId']!),
        routes: [
          GoRoute(path: 'group-info', builder: (_, s) => GroupInfoPage(chatId: s.pathParameters['chatId']!)),
          GoRoute(path: 'media', builder: (_, s) => ChatMediaPage(chatId: s.pathParameters['chatId']!)),
        ],
      ),
      GoRoute(
        path: '/join/:chatId/:code',
        builder: (_, s) => JoinGroupPage(chatId: s.pathParameters['chatId']!, code: s.pathParameters['code']!),
      ),
      GoRoute(path: AppRoutes.wallpaper, builder: (_, s) => WallpaperPage(chatId: s.uri.queryParameters['chatId'])),
      GoRoute(path: '/user/:uid', builder: (_, s) => UserProfilePage(uid: s.pathParameters['uid']!)),
      GoRoute(path: AppRoutes.statusText, pageBuilder: (_, s) => _fadePage(s, const TextStatusEditorPage())),
      GoRoute(
        path: AppRoutes.statusImage,
        // The picked photo is passed in memory; if Android restarted the app while
        // the gallery was open it is gone, so go back instead of crashing.
        redirect: (_, s) => s.extra is File ? null : AppRoutes.home,
        pageBuilder: (_, s) => _fadePage(s, ImageStatusEditorPage(image: s.extra! as File)),
      ),
      GoRoute(
        path: '/status/view/:userId',
        pageBuilder: (_, s) => _fadePage(s, StatusViewerPage(userId: s.pathParameters['userId']!)),
      ),
      GoRoute(
        path: '/call/:callId',
        pageBuilder:
            (_, s) => _fadePage(
              s,
              CallPage(
                callId: s.pathParameters['callId']!,
                args:
                    (s.extra as CallRouteArgs?) ??
                    const CallRouteArgs(isVideo: false, displayName: 'Call', isGroup: false),
              ),
            ),
      ),
      GoRoute(
        path: '/incoming-call/:callId',
        pageBuilder: (_, s) => _fadePage(s, IncomingCallPage(call: s.extra! as CallEntity)),
      ),
    ],
  );
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 280),
  transitionsBuilder:
      (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(animation), child: child),
      ),
);

/// Adapts a stream into a [Listenable] for GoRouter refreshes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
