import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../../domain/entities/status_entity.dart';
import '../bloc/status_bloc.dart';

/// Instagram-style story viewer: progress bars, tap to skip, hold to pause,
/// swipe down to close, auto-advance across people.
class StatusViewerPage extends StatefulWidget {
  const StatusViewerPage({super.key, required this.userId});
  final String userId;

  @override
  State<StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends State<StatusViewerPage> with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 6);

  late final AnimationController _progress = AnimationController(vsync: this, duration: _storyDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });

  /// Snapshot of the feed order when opened (stable while viewing).
  late List<UserStatuses> _groups;
  late String _me;
  int _group = 0;
  int _story = 0;
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    final state = context.read<StatusBloc>().state;
    _me = state.me;
    _groups = widget.userId == _me ? [if (state.mine != null) state.mine!] : state.others;
    _group = _groups.indexWhere((g) => g.userId == widget.userId).clamp(0, _groups.isEmpty ? 0 : _groups.length - 1);
    if (_groups.isNotEmpty) _story = widget.userId == _me ? 0 : _groups[_group].firstUnseenIndex(_me);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  StatusEntity? get _current =>
      _groups.isEmpty || _story >= _groups[_group].statuses.length ? null : _groups[_group].statuses[_story];

  Future<void> _start() async {
    final s = _current;
    if (s == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _progress
      ..stop()
      ..reset();
    if (s.type == StatusType.image && s.mediaUrl != null) {
      try {
        await precacheImage(CachedNetworkImageProvider(s.mediaUrl!), context);
      } catch (_) {}
    }
    if (!mounted || _current != s) return;
    context.read<StatusBloc>().add(StatusViewed(s));
    _progress.forward();
  }

  void _next() {
    final g = _groups[_group];
    if (_story < g.statuses.length - 1) {
      setState(() => _story++);
    } else if (_group < _groups.length - 1) {
      setState(() {
        _group++;
        _story = _groups[_group].firstUnseenIndex(_me);
      });
    } else {
      Navigator.pop(context);
      return;
    }
    _start();
  }

  void _previous() {
    if (_story > 0) {
      setState(() => _story--);
    } else if (_group > 0) {
      setState(() {
        _group--;
        _story = 0;
      });
    } else {
      _progress.forward(from: 0);
      return;
    }
    _start();
  }

  void _showViewers(StatusEntity s) {
    _progress.stop();
    final users = context.read<ChatListBloc>().state.users;
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(tr('Viewed by {0}', [s.viewers.length]), style: Theme.of(ctx).textTheme.titleLarge),
                ),
                if (s.viewers.isEmpty)
                  Padding(padding: EdgeInsets.all(20), child: Text(tr('No views yet')))
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final v in s.viewers)
                          ListTile(
                            leading: AppAvatar(name: users[v]?.name ?? '?', imageUrl: users[v]?.photoUrl, size: 40),
                            title: Text(users[v]?.name ?? tr('Someone')),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    ).whenComplete(() {
      if (mounted) _progress.forward();
    });
  }

  Future<void> _delete(StatusEntity s) async {
    _progress.stop();
    final ok = await AppFeedback.confirm(
      context,
      title: tr('Delete story?'),
      message: tr('It will be removed for everyone.'),
      confirmLabel: tr('Delete'),
      destructive: true,
    );
    if (!mounted) return;
    if (ok) {
      context.read<StatusBloc>().add(StatusDeleted(s));
      Navigator.pop(context);
    } else {
      _progress.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _current;
    if (s == null) return const Scaffold(backgroundColor: Colors.black);
    final group = _groups[_group];
    final users = context.select((ChatListBloc b) => b.state.users);
    final isMine = group.userId == _me;
    final user = users[group.userId];
    final name = isMine ? tr('My story') : (user?.name ?? '');
    final width = MediaQuery.sizeOf(context).width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTapUp: (d) => d.globalPosition.dx < width / 3 ? _previous() : _next(),
          onLongPressStart: (_) => _progress.stop(),
          onLongPressEnd: (_) => _progress.forward(),
          onVerticalDragUpdate: (d) => setState(() => _dragY = (_dragY + d.delta.dy).clamp(0.0, 400.0)),
          onVerticalDragEnd: (d) {
            if (_dragY > 120 || (d.primaryVelocity ?? 0) > 700) {
              Navigator.pop(context);
            } else {
              setState(() => _dragY = 0);
            }
          },
          child: Transform.translate(
            offset: Offset(0, _dragY),
            child: Opacity(
              opacity: (1 - _dragY / 600).clamp(0.3, 1.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(key: ValueKey(s.id), child: _StoryContent(status: s)),
                  ),
                  // Top scrim + progress + header
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(10, MediaQuery.paddingOf(context).top + 8, 10, 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _progress,
                            builder:
                                (_, __) => Row(
                                  children: [
                                    for (var i = 0; i < group.statuses.length; i++)
                                      Expanded(
                                        child: Container(
                                          height: 3,
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white30,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: i < _story ? 1.0 : (i == _story ? _progress.value : 0.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              AppAvatar(name: user?.name ?? name, imageUrl: user?.photoUrl, size: 38),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      Formatters.relative(s.createdAt),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (isMine)
                                IconButton(
                                  onPressed: () => _delete(s),
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isMine)
                    Positioned(
                      bottom: MediaQuery.paddingOf(context).bottom + 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => _showViewers(s),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.14),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                          icon: const Icon(Icons.visibility_rounded),
                          label: Text('${s.viewers.length}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  const _StoryContent({required this.status});
  final StatusEntity status;

  @override
  Widget build(BuildContext context) {
    if (status.type == StatusType.text) {
      return Container(
        color: Color(status.backgroundColor),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Text(
          status.text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, height: 1.3),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: status.mediaUrl ?? '', fit: BoxFit.contain),
        if (status.text.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 40, 24, MediaQuery.paddingOf(context).bottom + 72),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Text(
                status.text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
            ),
          ),
      ],
    );
  }
}
