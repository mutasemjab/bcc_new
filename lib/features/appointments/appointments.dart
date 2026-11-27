import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/di.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/services/chat_notifications.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/gradient_button.dart';

/// A saved appointment with an optional reminder.
class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.at,
    this.note = '',
    this.remindBefore,
    this.chatId,
  });

  final String id;
  final String title;
  final DateTime at;
  final String note;

  /// null = no reminder.
  final Duration? remindBefore;
  final String? chatId;

  int get reminderId => (tr('appt{0}', [id])).hashCode & 0x7FFFFFFF;
  DateTime? get remindAt => remindBefore == null ? null : at.subtract(remindBefore!);
}

/// Appointments stored privately under my account (synced across devices);
/// reminders are scheduled on this device.
class AppointmentsStore extends ChangeNotifier {
  AppointmentsStore(this._db);
  final FirebaseFirestore _db;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  List<Appointment> _items = const [];
  List<Appointment> get items => _items;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection(FirestorePaths.users).doc(uid).collection('appointments');

  void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _sub = _col(uid).orderBy('at').snapshots().listen((s) {
      _items = [
        for (final d in s.docs)
          Appointment(
            id: d.id,
            title: d.data()['title'] as String? ?? '',
            at: (d.data()['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
            note: d.data()['note'] as String? ?? '',
            remindBefore:
                d.data()['remindMinutes'] == null
                    ? null
                    : Duration(minutes: (d.data()['remindMinutes'] as num).toInt()),
            chatId: d.data()['chatId'] as String?,
          ),
      ];
      // Re-arm reminders on this device (e.g. after reinstall or another device's edit).
      for (final a in _items) {
        final at = a.remindAt;
        if (at != null && at.isAfter(DateTime.now())) {
          ChatNotifications.scheduleReminder(
            id: a.reminderId,
            title: '📅 ${a.title}',
            body: tr('At {0}{1}', [DateFormat.jm().format(a.at), a.note.isEmpty ? '' : ' • ${a.note}']),
            at: at,
          );
        }
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    _items = const [];
    notifyListeners();
  }

  Future<void> save({
    String? id,
    required String title,
    required DateTime at,
    String note = '',
    Duration? remindBefore,
    String? chatId,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = id == null ? _col(uid).doc() : _col(uid).doc(id);
    final old = id == null ? null : _items.where((a) => a.id == id).firstOrNull;
    if (old != null) await ChatNotifications.cancel(old.reminderId);
    await ref.set({
      'title': title,
      'at': Timestamp.fromDate(at),
      'note': note,
      'remindMinutes': remindBefore?.inMinutes,
      if (chatId != null) 'chatId': chatId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(Appointment a) async {
    final uid = _uid;
    if (uid == null) return;
    await ChatNotifications.cancel(a.reminderId);
    await _col(uid).doc(a.id).delete();
  }
}

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = sl<AppointmentsStore>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Appointments'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAppointmentEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('New')),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final upcoming = store.items.where((a) => a.at.isAfter(now)).toList();
          final past = store.items.where((a) => !a.at.isAfter(now)).toList().reversed.toList();
          if (store.items.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_rounded,
              title: tr('No appointments'),
              message: tr('Save appointments here and get a reminder before they start.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (upcoming.isNotEmpty) _Header(tr('Upcoming')),
              for (final a in upcoming) _Tile(a),
              if (past.isNotEmpty) _Header(tr('Past')),
              for (final a in past) _Tile(a, past: true),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.a, {this.past = false});
  final Appointment a;
  final bool past;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: past ? 0.55 : 1,
      child: ListTile(
        leading: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat.MMM().format(a.at), style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              Text(
                '${a.at.day}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
        ),
        title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            DateFormat('EEE, h:mm a').format(a.at),
            if (a.remindBefore != null) '🔔 ${_reminderLabel(a.remindBefore!)}',
            if (a.note.isNotEmpty) a.note,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => showAppointmentEditor(context, existing: a),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            final ok = await AppFeedback.confirm(
              context,
              title: tr('Delete appointment?'),
              message: a.title,
              confirmLabel: tr('Delete'),
              destructive: true,
            );
            if (ok) await sl<AppointmentsStore>().delete(a);
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
    ),
  );
}

const _reminderOptions = <Duration?>[null, Duration.zero, Duration(minutes: 15), Duration(hours: 1), Duration(days: 1)];

String _reminderLabel(Duration d) {
  if (d == Duration.zero) return tr('At the time');
  if (d.inDays >= 1) return tr('{0} day before', [d.inDays]);
  if (d.inHours >= 1) return tr('{0} hour before', [d.inHours]);
  return tr('{0} min before', [d.inMinutes]);
}

/// Create or edit an appointment (also used from "Add to appointments" on a message).
Future<void> showAppointmentEditor(
  BuildContext context, {
  Appointment? existing,
  String? initialTitle,
  String? chatId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _Editor(existing: existing, initialTitle: initialTitle, chatId: chatId),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({this.existing, this.initialTitle, this.chatId});
  final Appointment? existing;
  final String? initialTitle;
  final String? chatId;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? widget.initialTitle ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _at = widget.existing?.at ?? DateTime.now().add(const Duration(hours: 1));
  late Duration? _remind = widget.existing?.remindBefore ?? const Duration(minutes: 15);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      AppFeedback.error(context, tr('Give the appointment a title.'));
      return;
    }
    setState(() => _saving = true);
    await sl<AppointmentsStore>().save(
      id: widget.existing?.id,
      title: _title.text.trim(),
      at: _at,
      note: _note.text.trim(),
      remindBefore: _remind,
      chatId: widget.chatId ?? widget.existing?.chatId,
    );
    if (!mounted) return;
    AppFeedback.info(context, tr('Appointment saved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? tr('New appointment') : tr('Edit appointment'),
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: widget.existing == null && widget.initialTitle == null,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(hintText: tr('Title (e.g. Meeting with Ahmad)')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(DateFormat('EEE, d MMM yyyy').format(_at)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(DateFormat.jm().format(_at)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<Duration?>(
            initialValue: _remind,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.notifications_active_rounded)),
            items: [
              for (final r in _reminderOptions)
                DropdownMenuItem(value: r, child: Text(r == null ? tr('No reminder') : _reminderLabel(r))),
            ],
            onChanged: (v) => setState(() => _remind = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: _note, decoration: InputDecoration(hintText: tr('Note (optional)'))),
          const SizedBox(height: 18),
          GradientButton(label: tr('Save'), icon: Icons.check_rounded, isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
