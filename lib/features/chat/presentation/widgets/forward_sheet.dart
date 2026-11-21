import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../users/presentation/block_list.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/chat_extras.dart';
import '../bloc/chat_list/chat_list_bloc.dart';

/// WhatsApp-style "Forward to…" picker (up to 5 chats).
Future<void> showForwardSheet(BuildContext context, MessageEntity message) async {
  final list = context.read<ChatListBloc>().state;
  final me = list.uid;
  final blocked = sl<BlockList>();
  final chats =
      list.chats
          .where((c) => !c.isDeletedFor(me))
          .where((c) => !c.isGroup || c.participants.contains(me))
          .where((c) => c.isGroup || !blocked.isBlocked(c.peerId(me)))
          .toList();

  final selected = await showModalBottomSheet<List<ChatEntity>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ForwardPicker(chats: chats, titleOf: list.titleOf, photoOf: list.photoOf),
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;

  final r = await sl<ChatTools>().forward(message, me, [
    for (final c in selected) (chatId: c.id, participants: c.participants, isGroup: c.isGroup),
  ]);
  if (!context.mounted) return;
  r.match(
    (f) => AppFeedback.error(context, f.message),
    (_) =>
        AppFeedback.info(context, selected.length == 1 ? 'Message forwarded' : 'Forwarded to ${selected.length} chats'),
  );
}

class _ForwardPicker extends StatefulWidget {
  const _ForwardPicker({required this.chats, required this.titleOf, required this.photoOf});
  final List<ChatEntity> chats;
  final String Function(ChatEntity) titleOf;
  final String? Function(ChatEntity) photoOf;

  @override
  State<_ForwardPicker> createState() => _ForwardPickerState();
}

class _ForwardPickerState extends State<_ForwardPicker> {
  final _selected = <ChatEntity>[];
  String _query = '';

  void _toggle(ChatEntity c) {
    setState(() {
      if (_selected.contains(c)) {
        _selected.remove(c);
      } else if (_selected.length < ChatTools.maxForwardTargets) {
        _selected.add(c);
      } else {
        AppFeedback.info(context, 'You can share with up to 5 chats');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = widget.chats.where((c) => q.isEmpty || widget.titleOf(c).toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                Expanded(child: Text('Forward to…', style: context.text.titleLarge)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final c = visible[i];
                final on = _selected.contains(c);
                return ListTile(
                  onTap: () => _toggle(c),
                  leading: AppAvatar(
                    name: widget.titleOf(c),
                    imageUrl: widget.photoOf(c),
                    size: 44,
                    isGroup: c.isGroup,
                  ),
                  title: Text(widget.titleOf(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: on ? AppColors.primary : context.palette.stroke, width: 2),
                    ),
                    child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                  ),
                );
              },
            ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                color: context.palette.surfaceHigh,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selected.map(widget.titleOf).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: null,
                      backgroundColor: AppColors.primary,
                      onPressed: () => Navigator.pop(context, List.of(_selected)),
                      child: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
