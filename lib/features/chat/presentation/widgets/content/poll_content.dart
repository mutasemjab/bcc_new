import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../domain/entities/message_entity.dart';

/// A poll inside a chat bubble: tap to vote, live bars and percentages,
/// "View votes" shows who picked what.
class PollContent extends StatelessWidget {
  const PollContent({
    super.key,
    required this.message,
    required this.myId,
    required this.isMine,
    required this.onVote,
    required this.nameOf,
  });

  final MessageEntity message;
  final String myId;
  final bool isMine;
  final ValueChanged<List<String>> onVote;
  final String Function(String uid) nameOf;

  @override
  Widget build(BuildContext context) {
    final poll = message.poll;
    if (poll == null) return const SizedBox.shrink();
    final fg = isMine ? Colors.white : context.palette.incomingText;
    final muted = fg.withValues(alpha: 0.7);
    final counts = message.pollCounts;
    final voters = message.pollVotes.length;
    final mine = message.pollVotes[myId] ?? const <String>[];
    final top = counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    void toggle(String id) {
      HapticFeedback.selectionClick();
      final next =
          poll.allowMultiple
              ? (mine.contains(id) ? (List.of(mine)..remove(id)) : [...mine, id])
              : (mine.contains(id) ? <String>[] : [id]);
      onVote(next);
    }

    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, size: 18, color: muted),
              const SizedBox(width: 6),
              Text(
                poll.allowMultiple ? 'Poll • select one or more' : 'Poll • select one',
                style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(poll.question, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 10),
          for (final o in poll.options)
            _OptionRow(
              text: o.text,
              selected: mine.contains(o.id),
              multiple: poll.allowMultiple,
              count: counts[o.id] ?? 0,
              fraction: voters == 0 ? 0 : (counts[o.id] ?? 0) / voters,
              isLeading: top > 0 && (counts[o.id] ?? 0) == top,
              isMine: isMine,
              fg: fg,
              onTap: () => toggle(o.id),
            ),
          const SizedBox(height: 4),
          Divider(color: fg.withValues(alpha: 0.2), height: 12),
          Center(
            child: TextButton(
              onPressed: voters == 0 ? null : () => _showVotes(context, poll, counts),
              style: TextButton.styleFrom(foregroundColor: fg, visualDensity: VisualDensity.compact),
              child: Text(
                voters == 0 ? 'No votes yet' : 'View votes ($voters)',
                style: TextStyle(color: voters == 0 ? muted : fg, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVotes(BuildContext context, PollData poll, Map<String, int> counts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.92,
            builder:
                (_, scroll) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Text(poll.question, style: ctx.text.titleLarge),
                    const SizedBox(height: 12),
                    for (final o in poll.options) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(o.text, style: ctx.text.titleSmall)),
                            Text(
                              '${counts[o.id] ?? 0} vote${(counts[o.id] ?? 0) == 1 ? '' : 's'}',
                              style: TextStyle(color: ctx.palette.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      for (final e in message.pollVotes.entries.where((e) => e.value.contains(o.id)))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: AppAvatar(name: nameOf(e.key), size: 34),
                          title: Text(e.key == myId ? 'You' : nameOf(e.key)),
                        ),
                      Divider(color: ctx.palette.stroke),
                    ],
                  ],
                ),
          ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.text,
    required this.selected,
    required this.multiple,
    required this.count,
    required this.fraction,
    required this.isLeading,
    required this.isMine,
    required this.fg,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool multiple;
  final int count;
  final double fraction;
  final bool isLeading;
  final bool isMine;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isMine ? Colors.white : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: multiple ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: multiple ? BorderRadius.circular(6) : null,
                color: selected ? accent : Colors.transparent,
                border: Border.all(color: selected ? accent : fg.withValues(alpha: 0.5), width: 2),
              ),
              child:
                  selected
                      ? Icon(Icons.check_rounded, size: 15, color: isMine ? AppColors.primaryDeep : Colors.white)
                      : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 14.5, height: 1.3))),
                      const SizedBox(width: 8),
                      Text(
                        '$count',
                        style: TextStyle(color: fg.withValues(alpha: 0.8), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(height: 6, color: fg.withValues(alpha: 0.18)),
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: fraction),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder:
                              (_, v, __) => FractionallySizedBox(
                                widthFactor: v.clamp(0.0, 1.0),
                                child: Container(height: 6, color: isLeading ? accent : accent.withValues(alpha: 0.6)),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
