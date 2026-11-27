import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/data/storage_data_source.dart';
import '../core/services/contacts_service.dart';
import '../core/services/media_picker_service.dart';
import '../core/services/phone_linker.dart';
import '../core/services/wallpaper_store.dart';
import '../core/services/push_service.dart';
import '../core/l10n/l10n.dart';
import '../core/theme/appearance_settings.dart';
import '../core/theme/theme_cubit.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/auth_usecases.dart';
import '../features/auth/presentation/bloc/email_auth/email_auth_bloc.dart';
import '../features/auth/presentation/bloc/phone_auth/phone_auth_bloc.dart';
import '../features/auth/presentation/bloc/session/session_bloc.dart';
import '../features/calls/data/datasources/call_remote_data_source.dart';
import '../features/calls/data/repositories/call_repository_impl.dart';
import '../features/calls/data/services/agora_rtc_service.dart';
import '../features/calls/domain/repositories/call_repository.dart';
import '../features/calls/domain/services/rtc_service.dart';
import '../features/calls/domain/usecases/call_usecases.dart';
import '../features/calls/presentation/bloc/call_log/call_log_cubit.dart';
import '../features/calls/presentation/bloc/call_session/call_session_bloc.dart';
import '../features/calls/presentation/bloc/incoming_call/incoming_call_cubit.dart';
import '../features/chat/data/datasources/chat_remote_data_source.dart';
import '../features/chat/data/repositories/chat_repository_impl.dart';
import '../features/chat/domain/repositories/chat_repository.dart';
import '../features/chat/domain/usecases/chat_extras.dart';
import '../features/chat/domain/usecases/chat_usecases.dart';
import '../features/chat/domain/usecases/group_usecases.dart';
import '../features/chat/domain/usecases/message_usecases.dart';
import '../features/chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../features/chat/presentation/bloc/conversation/conversation_bloc.dart';
import '../features/chat/presentation/foreground_notifier.dart';
import '../features/appointments/appointments.dart';
import '../features/chat/presentation/scheduled_dispatcher.dart';
import '../features/chat/presentation/auto_clear.dart';
import '../features/chat/presentation/email_invites.dart';
import '../features/chat/presentation/starred.dart';
import '../features/chat/presentation/widgets/stickers/my_stickers_store.dart';
import '../features/status/data/datasources/status_remote_data_source.dart';
import '../features/status/data/repositories/status_repository_impl.dart';
import '../features/status/domain/repositories/status_repository.dart';
import '../features/status/domain/usecases/status_usecases.dart';
import '../features/status/presentation/bloc/status_bloc.dart';
import '../features/users/data/datasources/user_remote_data_source.dart';
import '../features/users/data/repositories/user_repository_impl.dart';
import '../features/users/domain/repositories/user_repository.dart';
import '../features/users/domain/usecases/user_usecases.dart';
import '../features/users/presentation/block_list.dart';
import '../features/users/presentation/contact_sync.dart';
import '../features/users/presentation/bloc/profile/profile_bloc.dart';

/// Service locator. Composition root: the only place that knows concrete types.
final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // ── External ─────────────────────────────────────────────────────────
  final firestore =
      FirebaseFirestore.instance
        ..settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  sl
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)
    ..registerLazySingleton<FirebaseFirestore>(() => firestore)
    ..registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance)
    ..registerLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance)
    ..registerLazySingleton<FirebaseFunctions>(() => FirebaseFunctions.instance)
    ..registerSingleton<SharedPreferences>(await SharedPreferences.getInstance());

  // ── Core ─────────────────────────────────────────────────────────────
  sl
    ..registerLazySingleton<StorageDataSource>(() => FirebaseStorageDataSource(sl()))
    ..registerLazySingleton(() => MediaPickerService())
    ..registerLazySingleton(() => MyStickersStore(sl()))
    ..registerLazySingleton(() => ContactsService())
    ..registerLazySingleton(() => WallpaperStore(sl()))
    ..registerLazySingleton(() => AppearanceSettings(sl()))
    ..registerLazySingleton(() => L10n(sl()))
    ..registerLazySingleton(() => PhoneLinker(sl(), sl()))
    ..registerLazySingleton(() => StarredStore(sl()))
    ..registerLazySingleton(() => EmailInviteClaimer(sl(), sl()))
    ..registerLazySingleton(() => AutoClearService(sl()))
    ..registerLazySingleton(() => AppointmentsStore(sl()))
    ..registerLazySingleton(() => PushService(sl()))
    ..registerLazySingleton(() => ThemeCubit(sl()));

  _auth();
  _users();
  _chat();
  _calls();
  _status();
}

void _auth() {
  sl
    ..registerLazySingleton<AuthRemoteDataSource>(() => FirebaseAuthDataSource(sl()))
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    ..registerLazySingleton(() => WatchAuthState(sl()))
    ..registerLazySingleton(() => SignInWithEmail(sl()))
    ..registerLazySingleton(() => SignUpWithEmail(sl()))
    ..registerLazySingleton(() => SendPasswordReset(sl()))
    ..registerLazySingleton(() => SendPhoneCode(sl()))
    ..registerLazySingleton(() => VerifyPhoneCode(sl()))
    ..registerLazySingleton(() => GetCurrentAccount(sl()))
    ..registerLazySingleton(() => SignOut(sl()))
    ..registerLazySingleton(
      () => SessionBloc(
        watchAuthState: sl(),
        watchUser: sl(),
        setPresence: sl(),
        registerPushToken: sl(),
        signOut: sl(),
        pushService: sl(),
      ),
    )
    ..registerFactory(() => EmailAuthBloc(signIn: sl(), signUp: sl(), sendReset: sl()))
    ..registerFactory(() => PhoneAuthBloc(sendCode: sl(), verifyCode: sl()));
}

void _users() {
  sl
    ..registerLazySingleton<UserRemoteDataSource>(() => FirestoreUserDataSource(sl(), sl()))
    ..registerLazySingleton<UserRepository>(() => UserRepositoryImpl(sl()))
    ..registerLazySingleton(() => WatchUser(sl()))
    ..registerLazySingleton(() => WatchUsers(sl()))
    ..registerLazySingleton(() => GetUser(sl()))
    ..registerLazySingleton(() => SaveProfile(sl()))
    ..registerLazySingleton(() => SearchUsers(sl()))
    ..registerLazySingleton(() => FindUsersByPhones(sl()))
    ..registerLazySingleton(() => PrivacySettings(sl()))
    ..registerLazySingleton(() => BlockList(sl()))
    ..registerLazySingleton(() => ContactSync(sl(), sl()))
    ..registerLazySingleton(() => SetPresence(sl()))
    ..registerLazySingleton(() => RegisterPushToken(sl()))
    ..registerFactory(() => ProfileBloc(getCurrentAccount: sl(), getUser: sl(), saveProfile: sl()));
}

void _chat() {
  sl
    ..registerLazySingleton(() => ChatRemoteDataSource(sl(), sl()))
    ..registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(sl()))
    // chats
    ..registerLazySingleton(() => WatchChats(sl()))
    ..registerLazySingleton(() => WatchChat(sl()))
    ..registerLazySingleton(() => EnsureDirectChat(sl()))
    ..registerLazySingleton(() => SetTyping(sl()))
    ..registerLazySingleton(() => MarkChatRead(sl()))
    ..registerLazySingleton(() => TogglePinChat(sl()))
    ..registerLazySingleton(() => ToggleMuteChat(sl()))
    ..registerLazySingleton(() => MarkMessagesDelivered(sl()))
    // messages
    ..registerLazySingleton(() => WatchMessages(sl()))
    ..registerLazySingleton(() => SendMessage(sl()))
    ..registerLazySingleton(() => MarkMessagesRead(sl()))
    ..registerLazySingleton(() => DeleteMessage(sl()))
    ..registerLazySingleton(() => EditMessage(sl()))
    ..registerLazySingleton(() => ReactToMessage(sl()))
    ..registerLazySingleton(() => VotePoll(sl()))
    ..registerLazySingleton(() => GroupMembership(sl()))
    ..registerLazySingleton(() => ChatTools(sl()))
    ..registerLazySingleton(() => ScheduledDispatcher(sl()))
    ..registerLazySingleton(ForegroundNotifier.new)
    // groups
    ..registerLazySingleton(() => CreateGroup(sl()))
    ..registerLazySingleton(() => UpdateGroup(sl()))
    ..registerLazySingleton(() => AddGroupMembers(sl()))
    ..registerLazySingleton(() => RemoveGroupMember(sl()))
    ..registerLazySingleton(() => LeaveGroup(sl()))
    ..registerLazySingleton(() => SetGroupAdmin(sl()))
    // blocs
    ..registerLazySingleton(
      () => ChatListBloc(watchChats: sl(), watchUsers: sl(), togglePin: sl(), toggleMute: sl(), markDelivered: sl()),
    )
    ..registerFactory(
      () => ConversationBloc(
        watchChat: sl(),
        watchMessages: sl(),
        watchUsers: sl(),
        ensureDirectChat: sl(),
        sendMessage: sl(),
        markRead: sl(),
        markChatRead: sl(),
        setTyping: sl(),
        deleteMessage: sl(),
        editMessage: sl(),
        react: sl(),
        votePoll: sl(),
      ),
    );
}

void _calls() {
  sl
    ..registerLazySingleton(() => CallRemoteDataSource(sl(), sl()))
    ..registerLazySingleton<CallRepository>(() => CallRepositoryImpl(sl()))
    ..registerFactory<RtcService>(AgoraRtcService.new) // one engine per call
    ..registerLazySingleton(() => StartCall(sl()))
    ..registerLazySingleton(() => WatchCall(sl()))
    ..registerLazySingleton(() => WatchIncomingCalls(sl()))
    ..registerLazySingleton(() => WatchCallLog(sl()))
    ..registerLazySingleton(() => AcceptCall(sl()))
    ..registerLazySingleton(() => DeclineCall(sl()))
    ..registerLazySingleton(() => LeaveCall(sl()))
    ..registerLazySingleton(() => MarkCallMissed(sl()))
    ..registerLazySingleton(() => FetchRtcToken(sl()))
    ..registerLazySingleton(() => IncomingCallCubit(sl(), sl(), sl()))
    ..registerLazySingleton(() => CallLogCubit(sl()))
    ..registerFactory(
      () => CallSessionBloc(rtc: sl(), watchCall: sl(), fetchToken: sl(), leaveCall: sl(), markMissed: sl()),
    );
}

void _status() {
  sl
    ..registerLazySingleton(() => StatusRemoteDataSource(sl(), sl()))
    ..registerLazySingleton<StatusRepository>(() => StatusRepositoryImpl(sl()))
    ..registerLazySingleton(() => WatchStatusFeed(sl()))
    ..registerLazySingleton(() => PostTextStatus(sl()))
    ..registerLazySingleton(() => PostImageStatus(sl()))
    ..registerLazySingleton(() => MarkStatusViewed(sl()))
    ..registerLazySingleton(() => DeleteStatus(sl()))
    ..registerLazySingleton(
      () => StatusBloc(watchFeed: sl(), postText: sl(), postImage: sl(), markViewed: sl(), deleteStatus: sl()),
    );
}
