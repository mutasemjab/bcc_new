import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/usecases/chat_extras.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../widgets/join_identity_sheet.dart';

/// Opened from a group invite link: preview the group, then join.
class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key, required this.chatId, required this.code});
  final String chatId;
  final String code;

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  GroupInvitePreview? _preview;
  bool _loading = true;
  bool _joining = false;
  bool _alreadyMember = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionBloc>().state;
    final r = await sl<GroupMembership>().preview(widget.code);
    // Members can read the chat; for everyone else this read is denied.
    if (session is SessionAuthenticated) {
      try {
        final chat = await sl<WatchChat>()(widget.chatId).first.timeout(const Duration(seconds: 6));
        _alreadyMember = chat?.participants.contains(session.user.id) ?? false;
      } catch (_) {
        _alreadyMember = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _preview = r.fold((_) => null, (p) => p?.chatId == widget.chatId ? p : null);
      _loading = false;
    });
  }

  Future<void> _join() async {
    final session = context.read<SessionBloc>().state;
    final preview = _preview;
    if (session is! SessionAuthenticated || preview == null) return;
    final me = session.user;
    final choice = await chooseJoinIdentity(context, groupName: preview.name, myName: me.name, myPhotoUrl: me.photoUrl);
    if (choice == null || !mounted) return;
    setState(() => _joining = true);
    final alias = choice.alias;
    final r = await sl<GroupMembership>().joinWithLink(widget.chatId, widget.code, me.id, me.name, alias: alias);
    if (!mounted) return;
    setState(() => _joining = false);
    r.match((f) => AppFeedback.error(context, 'Could not join. The link may have been reset.'), (_) {
      if (alias != null) AppFeedback.info(context, 'You joined as $alias');
      context.pushReplacement(AppRoutes.conversation(widget.chatId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Group invite')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : p == null
              ? const EmptyState(
                icon: Icons.link_off_rounded,
                title: 'Link not valid',
                message: 'This invite link was reset or turned off by a group admin.',
              )
              : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    AppAvatar(name: p.name, imageUrl: p.photoUrl, size: 120, isGroup: true),
                    const SizedBox(height: 18),
                    Text(p.name, style: context.text.headlineSmall, textAlign: TextAlign.center),
                    if (p.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        p.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.palette.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      _alreadyMember
                          ? "You're already a member of this group."
                          : "You've been invited to join this group.",
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                    const Spacer(),
                    GradientButton(
                      label: _alreadyMember ? 'Open group' : 'Join group',
                      icon: _alreadyMember ? Icons.forum_rounded : Icons.group_add_rounded,
                      isLoading: _joining,
                      onPressed:
                          _alreadyMember ? () => context.pushReplacement(AppRoutes.conversation(widget.chatId)) : _join,
                    ),
                  ],
                ),
              ),
    );
  }
}
