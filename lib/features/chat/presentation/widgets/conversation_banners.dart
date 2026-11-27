import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/entities/scheduled_message.dart';
import '../../domain/usecases/chat_extras.dart';

/// Pinned messages bar under the app bar. Tapping jumps to the shown message
/// and then cycles to the next pin (like WhatsApp).
class PinnedMessagesBanner extends StatefulWidget {
  const PinnedMessagesBanner({
    super.key,
    required this.pins,
    required this.nameOf,
    required this.onJump,
    required this.onUnpin,
  });

  final List<PinnedMessage> pins;
  final String Function(String uid) nameOf;
  final ValueChanged<String> onJump;
  final ValueChanged<String>? onUnpin;

  @override
  State<PinnedMessagesBanner> createState() => _PinnedMessagesBannerState();
}

class _PinnedMessagesBannerState extends State<PinnedMessagesBanner> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pins = widget.pins;
    if (pins.isEmpty) return const SizedBox.shrink();
    final i = _index % pins.length;
    final pin = pins[i];

    return Material(
      color: context.theme.scaffoldBackgroundColor,
      child: InkWell(
        onTap: () {
          widget.onJump(pin.messageId);
          setState(() => _index = i + 1);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.palette.stroke.withValues(alpha: 0.7), width: 0.6)),
          ),
          child: Row(
            children: [
              // One segment per pin, the current one highlighted.
              Column(
                children: [
                  for (var k = 0; k < pins.length; k++)
                    Container(
                      width: 3,
                      height: pins.length == 1 ? 34 : 34 / pins.length - 2,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: k == i ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              const Icon(Icons.push_pin_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pins.length > 1 ? tr('Pinned message {0} of {1}', [i + 1, pins.length]) : tr('Pinned message'),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${widget.nameOf(pin.senderId)}: ${pin.preview}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (widget.onUnpin != null)
                IconButton(
                  tooltip: tr('Unpin'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: context.palette.textSecondary),
                  onPressed: () => widget.onUnpin!(pin.messageId),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2 scheduled messages" bar for the current chat.
class ScheduledMessagesBar extends StatelessWidget {
  const ScheduledMessagesBar({super.key, required this.chatId, required this.uid});
  final String chatId;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduledMessage>>(
      stream: sl<ChatTools>().scheduled(uid),
      builder: (context, snap) {
        final items = (snap.data ?? const <ScheduledMessage>[]).where((m) => m.chatId == chatId).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Material(
          color: AppColors.primary.withValues(alpha: 0.10),
          child: InkWell(
            onTap: () => showScheduledMessagesSheet(context, uid: uid, chatId: chatId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.schedule_send_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items.length == 1
                          ? tr('1 scheduled message • {0}', [_when(items.first.sendAt)])
                          : tr('{0} scheduled messages • next {1}', [items.length, _when(items.first.sendAt)]),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _when(DateTime t) {
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  final tomorrow = now.add(const Duration(days: 1));
  final isTomorrow = t.year == tomorrow.year && t.month == tomorrow.month && t.day == tomorrow.day;
  final time = DateFormat.Hm().format(t);
  if (sameDay) return tr('today {0}', [time]);
  if (isTomorrow) return tr('tomorrow {0}', [time]);
  return '${DateFormat.MMMd().format(t)} $time';
}

Future<void> showScheduledMessagesSheet(BuildContext context, {required String uid, required String chatId}) {
  final tools = sl<ChatTools>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder:
        (ctx) => SafeArea(
          child: StreamBuilder<List<ScheduledMessage>>(
            stream: tools.scheduled(uid),
            builder: (ctx, snap) {
              final items = (snap.data ?? const <ScheduledMessage>[]).where((m) => m.chatId == chatId).toList();
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(tr('Scheduled messages'), style: ctx.text.titleLarge),
                    ),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(tr('Nothing scheduled.'), style: TextStyle(color: ctx.palette.textSecondary)),
                      ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final m in items)
                            ListTile(
                              leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                              title: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(tr('Sends {0}', [_when(m.sendAt)])),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  final r =
                                      v == 'now'
                                          ? await tools.sendScheduledNow(m)
                                          : await tools.deleteScheduled(uid, m.id);
                                  if (ctx.mounted) {
                                    r.match((f) => AppFeedback.error(ctx, f.message), (_) {});
                                  }
                                },
                                itemBuilder:
                                    (_) => [
                                      PopupMenuItem(value: 'now', child: Text(tr('Send now'))),
                                      PopupMenuItem(value: 'delete', child: Text(tr('Delete'))),
                                    ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
  );
}

/// Date + time pickers; returns a moment at least one minute in the future.
/// "Send later": quick choices (in 1 / 3 / 8 hours, tomorrow morning) or a
/// custom date and time.
Future<DateTime?> pickScheduleTime(BuildContext context) async {
  final now = DateTime.now();
  final tomorrow9 = DateTime(now.year, now.month, now.day + 1, 9);
  final presets = <(String, DateTime)>[
    (tr('In 1 hour'), now.add(const Duration(hours: 1))),
    (tr('In 3 hours'), now.add(const Duration(hours: 3))),
    (tr('In 8 hours'), now.add(const Duration(hours: 8))),
    (tr('Tomorrow at 9:00 AM'), tomorrow9),
  ];
  final picked = await showModalBottomSheet<Object>(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(tr('Send later'), style: ctx.text.titleLarge),
              ),
              for (final (label, at) in presets)
                ListTile(
                  leading: const Icon(Icons.schedule_send_rounded, color: AppColors.primary),
                  title: Text(label),
                  subtitle: Text(_when(at)),
                  onTap: () => Navigator.pop(ctx, at),
                ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary),
                title: Text(tr('Pick date & time')),
                onTap: () => Navigator.pop(ctx, 'custom'),
              ),
            ],
          ),
        ),
  );
  if (picked is DateTime) return picked;
  if (picked != 'custom' || !context.mounted) return null;

  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
    helpText: tr('Send on'),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
    helpText: tr('Send at'),
  );
  if (time == null) return null;
  final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (!at.isAfter(DateTime.now())) {
    if (context.mounted) AppFeedback.error(context, tr('Pick a time in the future.'));
    return null;
  }
  return at;
}
