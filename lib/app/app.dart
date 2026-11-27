import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/config/env.dart';
import '../core/services/chat_notifications.dart';
import '../core/services/push_service.dart';
import '../core/theme/app_theme.dart';
import '../core/l10n/l10n.dart';
import '../core/theme/appearance_settings.dart';
import '../core/theme/theme_cubit.dart';
import '../features/auth/presentation/bloc/session/session_bloc.dart';
import '../features/calls/domain/entities/call_entity.dart';
import '../features/calls/presentation/bloc/call_log/call_log_cubit.dart';
import '../features/calls/presentation/bloc/incoming_call/incoming_call_cubit.dart';
import '../features/chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../features/chat/presentation/foreground_notifier.dart';
import '../features/appointments/appointments.dart';
import '../features/chat/presentation/scheduled_dispatcher.dart';
import '../features/chat/presentation/auto_clear.dart';
import '../features/chat/presentation/email_invites.dart';
import '../features/chat/presentation/starred.dart';
import '../features/status/presentation/bloc/status_bloc.dart';
import '../features/users/presentation/block_list.dart';
import '../features/users/presentation/contact_sync.dart';
import 'di.dart';
import 'router.dart';
import 'routes.dart';

class BccChatApp extends StatefulWidget {
  const BccChatApp({super.key});

  @override
  State<BccChatApp> createState() => _BccChatAppState();
}

class _BccChatAppState extends State<BccChatApp> {
  late final SessionBloc _session = sl<SessionBloc>()..add(const SessionStarted());
  late final GoRouter _router = buildRouter(_session);
  late final AppLifecycleListener _lifecycle;

  StreamSubscription<RemoteMessage>? _pushTapSub;

  @override
  void initState() {
    super.initState();
    _listenForNotificationTaps();
    // Presence: online while the app is in the foreground.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        sl<L10n>().systemLocaleChanged();
        _session.add(const SessionForegroundChanged(true));
        _startHeartbeat();
      },
      onPause: () {
        _heartbeat?.cancel();
        _session.add(const SessionForegroundChanged(false));
      },
      onDetach: () {
        _heartbeat?.cancel();
        _session.add(const SessionForegroundChanged(false));
      },
    );
    _startHeartbeat();
  }

  /// "Online" heartbeat every minute while the app is on screen. If the app
  /// is killed the heartbeats stop and others see me offline within 2 minutes.
  Timer? _heartbeat;
  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_session.state is SessionAuthenticated) _session.add(const SessionForegroundChanged(true));
    });
  }

  /// Opening a notification jumps straight into that chat — whether it was a
  /// system push (iOS) or one of our own grouped notifications (Android).
  Future<void> _listenForNotificationTaps() async {
    final push = sl<PushService>();

    Future<void> afterLogin(VoidCallback go) async {
      if (_session.state is! SessionAuthenticated) {
        await _session.stream.firstWhere((s) => s is SessionAuthenticated);
      }
      go();
    }

    void openChat(String? chatId) {
      if (chatId == null || chatId.isEmpty) return;
      afterLogin(() => _router.push(AppRoutes.conversation(chatId)));
    }

    void openPayload(String? payload) {
      if (payload == null) return;
      if (payload.startsWith('chat:')) openChat(payload.substring(5));
      if (payload.startsWith('invite:')) afterLogin(() => _router.go(AppRoutes.home));
    }

    void openRemote(RemoteMessage m) {
      if (m.data['type'] == 'message') openChat(m.data['chatId'] as String?);
      if (m.data['type'] == 'group_invite') afterLogin(() => _router.go(AppRoutes.home));
    }

    await ChatNotifications.init(onTap: openPayload);
    _pushTapSub = push.onMessageOpenedApp.listen(openRemote);

    // Launched from "closed" by tapping a notification.
    final launch = await ChatNotifications.launchPayload();
    if (launch != null) {
      openPayload(launch);
      return;
    }
    final initial = await push.initialMessage();
    if (initial != null) openRemote(initial);
  }

  @override
  void dispose() {
    _pushTapSub?.cancel();
    _heartbeat?.cancel();
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<ThemeCubit>()),
        BlocProvider.value(value: _session),
        BlocProvider.value(value: sl<ChatListBloc>()),
        BlocProvider.value(value: sl<StatusBloc>()),
        BlocProvider.value(value: sl<IncomingCallCubit>()),
        BlocProvider.value(value: sl<CallLogCubit>()),
      ],
      child: _SessionCoordinator(
        router: _router,
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder:
              (context, mode) => ListenableBuilder(
                // Font family + text size chosen in Settings → Font.
                // Font / text size (Settings → Font) and language (Settings → Language).
                listenable: Listenable.merge([sl<AppearanceSettings>(), sl<L10n>()]),
                builder: (context, _) {
                  final look = sl<AppearanceSettings>();
                  return MaterialApp.router(
                    // New language → rebuild every screen with the new texts.
                    key: ValueKey(sl<L10n>().locale.languageCode),
                    title: Env.appName,
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.themed(Brightness.light, look.font),
                    darkTheme: AppTheme.themed(Brightness.dark, look.font),
                    themeMode: mode,
                    routerConfig: _router,
                    // Arabic → right-to-left everywhere, plus Arabic date/time pickers etc.
                    locale: sl<L10n>().locale,
                    supportedLocales: const [Locale('en'), Locale('ar')],
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    builder:
                        (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(look.scale)),
                          child: child!,
                        ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// Starts/stops session-scoped real-time streams and routes incoming calls.
class _SessionCoordinator extends StatelessWidget {
  const _SessionCoordinator({required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionBloc, SessionState>(
          listenWhen: (p, c) => p.runtimeType != c.runtimeType,
          listener: (context, state) {
            if (state is SessionAuthenticated) {
              final uid = state.user.id;
              context.read<ChatListBloc>().add(ChatListStarted(uid));
              context.read<CallLogCubit>().start(uid);
              context.read<IncomingCallCubit>().start(uid);
              sl<ScheduledDispatcher>().start(uid);
              sl<BlockList>().start(uid);
              sl<StarredStore>().start(uid);
              // Group invitations sent to my email before I had an account.
              sl<EmailInviteClaimer>().start();
              sl<AppointmentsStore>().start(uid);
              // Background contact discovery (cached on the device).
              sl<ContactSync>().start(uid, myPhone: state.user.phone);
              context.read<StatusBloc>().add(StatusFeedStarted(me: uid, contacts: const {}));
            } else {
              context.read<ChatListBloc>().add(const ChatListStopped());
              context.read<CallLogCubit>().stop();
              context.read<IncomingCallCubit>().stop();
              sl<ScheduledDispatcher>().stop();
              sl<ForegroundNotifier>().reset();
              sl<BlockList>().stop();
              sl<StarredStore>().stop();
              sl<EmailInviteClaimer>().stop();
              sl<AppointmentsStore>().stop();
              sl<ContactSync>().stop();
              context.read<StatusBloc>().add(const StatusFeedStopped());
            }
          },
        ),
        // In-app notifications for new messages in other chats.
        BlocListener<ChatListBloc, ChatListState>(
          listenWhen: (p, c) => !identical(p.chats, c.chats),
          listener: (context, state) {
            sl<ForegroundNotifier>().onChats(state, blocked: sl<BlockList>().blocked);
            sl<AutoClearService>().onChats(state);
          },
        ),
        // Stories follow the people you talk to.
        BlocListener<ChatListBloc, ChatListState>(
          listenWhen: (p, c) => p.users.keys.length != c.users.keys.length || p.uid != c.uid,
          listener: (context, state) {
            if (state.uid.isEmpty) return;
            context.read<StatusBloc>().add(StatusFeedStarted(me: state.uid, contacts: state.users.keys.toSet()));
          },
        ),
        // Ring!
        BlocListener<IncomingCallCubit, CallEntity?>(
          listenWhen: (p, c) => c != null && p?.id != c.id,
          listener: (context, call) {
            if (call == null) return;
            router.push(AppRoutes.incomingCall(call.id), extra: call);
          },
        ),
      ],
      child: child,
    );
  }
}
