import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/di.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/presentation/bloc/session/session_bloc.dart';
import '../../chat/domain/entities/chat_entity.dart';
import '../../users/domain/entities/user_entity.dart';
import '../domain/entities/call_entity.dart';
import '../domain/usecases/call_usecases.dart';

/// Entry point for placing a call from any screen.
abstract final class CallLauncher {
  static Future<bool> ensurePermissions(BuildContext context, {required bool video}) async {
    final statuses = await [Permission.microphone, if (video) Permission.camera].request();
    final granted = statuses.values.every((s) => s.isGranted);
    if (!granted && context.mounted) {
      AppFeedback.error(
        context,
        video
            ? tr('Camera and microphone access are needed for video calls.')
            : tr('Microphone access is needed for calls.'),
      );
    }
    return granted;
  }

  static Future<void> start(
    BuildContext context, {
    required ChatEntity chat,
    required Map<String, UserEntity> users,
    required CallType type,
  }) async {
    final session = context.read<SessionBloc>().state;
    if (session is! SessionAuthenticated) return;
    if (!await ensurePermissions(context, video: type == CallType.video)) return;

    final me = session.user;
    final peer = chat.isGroup ? null : users[chat.peerId(me.id)];
    final result = await sl<StartCall>()(
      StartCallParams(
        chatId: chat.id,
        callerId: me.id,
        // Anonymous group members call under their alias, without a photo.
        callerName: chat.aliasOf(me.id) ?? me.name,
        callerPhoto: chat.isAnonymous(me.id) ? null : me.photoUrl,
        participants: chat.participants,
        isGroup: chat.isGroup,
        // Title as the *callee* sees it (they see who is calling, or the group).
        title: chat.isGroup ? (chat.name ?? tr('Group call')) : me.name,
        photoUrl: chat.isGroup ? chat.photoUrl : me.photoUrl,
        type: type,
      ),
    );
    if (!context.mounted) return;
    result.match(
      (f) => AppFeedback.error(context, f.message),
      (call) => context.push(
        AppRoutes.call(call.id),
        extra: CallRouteArgs(
          isVideo: type == CallType.video,
          displayName: chat.isGroup ? (chat.name ?? tr('Group call')) : (peer?.name ?? ''),
          displayPhoto: chat.isGroup ? chat.photoUrl : peer?.photoUrl,
          isGroup: chat.isGroup,
        ),
      ),
    );
  }
}

/// What the call screen should show before the call doc loads.
class CallRouteArgs {
  const CallRouteArgs({required this.isVideo, required this.displayName, this.displayPhoto, required this.isGroup});
  final bool isVideo;
  final String displayName;
  final String? displayPhoto;
  final bool isGroup;
}
