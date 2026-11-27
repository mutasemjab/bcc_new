import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:ui' show FontFeature;

import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/pressable.dart';
import '../../domain/entities/message_entity.dart';
import '../bloc/voice_recorder/voice_recorder_cubit.dart';
import 'stickers/sticker_panel.dart';

/// Bottom input bar: text, emoji panel, attachments, and voice notes.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.onTypingChanged,
    required this.onAttach,
    required this.onCamera,
    required this.onVoiceRecorded,
    required this.onSticker,
    required this.onCustomSticker,
    this.onSchedule,
    this.replyingTo,
    this.replyingToName,
    this.editing,
    this.onCancelReplyOrEdit,
  });

  final ValueChanged<String> onSend;
  final ValueChanged<bool> onTypingChanged;
  final VoidCallback onAttach;
  final VoidCallback onCamera;

  /// Called with the finished voice note and whether it is "view once".
  final void Function(VoiceRecording recording, bool viewOnce) onVoiceRecorded;
  final ValueChanged<String> onSticker;
  final ValueChanged<File> onCustomSticker;

  /// Long-press on send: schedule the typed text. Returns true when scheduled.
  final Future<bool> Function(String text)? onSchedule;
  final MessageEntity? replyingTo;
  final String? replyingToName;
  final MessageEntity? editing;
  final VoidCallback? onCancelReplyOrEdit;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _showEmoji = false;
  bool _stickerTab = false;

  // ── WhatsApp-style voice recording ──
  // Hold the mic → record. Release → send. Slide left → cancel. Slide up → lock.
  bool _holding = false;
  bool _locked = false;
  bool _voiceViewOnce = false;
  double _dragX = 0;
  double _dragY = 0;
  static const _cancelDistance = 110.0;
  static const _lockDistance = 80.0;

  VoiceRecorderCubit get _recorder => context.read<VoiceRecorderCubit>();

  Future<void> _onMicDown(LongPressStartDetails _) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _holding = true;
      _locked = false;
      _voiceViewOnce = false;
      _dragX = 0;
      _dragY = 0;
    });
    await _recorder.start();
    if (!mounted) return;
    if (_recorder.state.permissionDenied) {
      setState(() => _holding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('Allow microphone access to record voice messages.'))));
    }
  }

  void _onMicMove(LongPressMoveUpdateDetails d) {
    if (!_holding || _locked) return;
    setState(() {
      _dragX = d.offsetFromOrigin.dx.clamp(-_cancelDistance - 20, 0);
      _dragY = d.offsetFromOrigin.dy.clamp(-_lockDistance - 20, 0);
    });
    if (_dragX <= -_cancelDistance) {
      HapticFeedback.heavyImpact();
      setState(() => _holding = false);
      _recorder.cancel();
    } else if (_dragY <= -_lockDistance) {
      HapticFeedback.mediumImpact();
      setState(() {
        _locked = true;
        _dragX = 0;
        _dragY = 0;
      });
    }
  }

  Future<void> _onMicUp(LongPressEndDetails _) async {
    if (!_holding || _locked) return;
    setState(() => _holding = false);
    await _finishRecording();
  }

  Future<void> _finishRecording() async {
    final viewOnce = _voiceViewOnce;
    setState(() {
      _holding = false;
      _locked = false;
      _voiceViewOnce = false;
    });
    final rec = await _recorder.stop();
    if (rec != null) {
      HapticFeedback.lightImpact();
      widget.onVoiceRecorded(rec, viewOnce);
    }
  }

  void _discardRecording() {
    setState(() {
      _holding = false;
      _locked = false;
      _voiceViewOnce = false;
    });
    _recorder.cancel();
  }

  void _micHint() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(tr('Hold to record, release to send')), duration: Duration(milliseconds: 1400)),
      );
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
      widget.onTypingChanged(_controller.text.isNotEmpty);
    });
    _focus.addListener(() {
      if (_focus.hasFocus && _showEmoji) setState(() => _showEmoji = false);
    });
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (widget.editing != null && widget.editing != old.editing) {
      _controller.text = widget.editing!.text;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      _focus.requestFocus();
    }
    if (widget.replyingTo != null && widget.replyingTo != old.replyingTo) _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSend(text);
    _controller.clear();
  }

  Future<void> _schedule() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.onSchedule == null) return;
    HapticFeedback.mediumImpact();
    if (await widget.onSchedule!(text) && mounted) _controller.clear();
  }

  /// Select text → Bold / Italic / Strikethrough / Monospace. Wraps the
  /// selection in markers that the message bubble renders.
  Widget _formattingMenu(BuildContext context, EditableTextState editable) {
    final sel = _controller.selection;
    final items = [...editable.contextMenuButtonItems];
    if (sel.isValid && !sel.isCollapsed) {
      void wrap(String marker) {
        final text = _controller.text;
        final start = sel.start, end = sel.end;
        _controller.value = TextEditingValue(
          text: text.replaceRange(start, end, '$marker${text.substring(start, end)}$marker'),
          selection: TextSelection(baseOffset: start + marker.length, extentOffset: end + marker.length),
        );
        ContextMenuController.removeAny();
      }

      items.addAll([
        ContextMenuButtonItem(label: tr('Bold'), onPressed: () => wrap('*')),
        ContextMenuButtonItem(label: tr('Italic'), onPressed: () => wrap('_')),
        ContextMenuButtonItem(label: tr('Strikethrough'), onPressed: () => wrap('~')),
        ContextMenuButtonItem(label: tr('Monospace'), onPressed: () => wrap('```')),
      ]);
    }
    return AdaptiveTextSelectionToolbar.buttonItems(anchors: editable.contextMenuAnchors, buttonItems: items);
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      SystemChannels.textInput.invokeMethod<void>(tr('TextInput.hide'));
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final recorder = context.watch<VoiceRecorderCubit>().state;

    return Container(
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: palette.stroke.withValues(alpha: 0.6), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child:
                  (widget.replyingTo != null || widget.editing != null)
                      ? _ContextBar(
                        title:
                            widget.editing != null
                                ? tr('Edit message')
                                : tr('Replying to {0}', [widget.replyingToName ?? '']),
                        preview: (widget.editing ?? widget.replyingTo)!.preview,
                        icon: widget.editing != null ? Icons.edit_rounded : Icons.reply_rounded,
                        onClose: () {
                          if (widget.editing != null) _controller.clear();
                          widget.onCancelReplyOrEdit?.call();
                        },
                      )
                      : const SizedBox(width: double.infinity),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: _inputRow(context, palette, recorder)),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child:
                  _showEmoji
                      ? SizedBox(
                        height: 320,
                        child: Column(
                          children: [
                            _PanelTabs(stickers: _stickerTab, onChanged: (v) => setState(() => _stickerTab = v)),
                            Expanded(
                              child:
                                  _stickerTab
                                      ? StickerPanel(
                                        onSticker: widget.onSticker,
                                        onCustomSticker: widget.onCustomSticker,
                                      )
                                      : EmojiPicker(
                                        textEditingController: _controller,
                                        config: Config(
                                          height: 274,
                                          emojiViewConfig: EmojiViewConfig(
                                            backgroundColor: context.theme.scaffoldBackgroundColor,
                                            columns: 8,
                                            emojiSizeMax: 28,
                                          ),
                                          categoryViewConfig: CategoryViewConfig(
                                            backgroundColor: context.theme.scaffoldBackgroundColor,
                                            indicatorColor: AppColors.primary,
                                            iconColorSelected: AppColors.primary,
                                          ),
                                          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                                          searchViewConfig: SearchViewConfig(
                                            backgroundColor: context.theme.scaffoldBackgroundColor,
                                          ),
                                        ),
                                      ),
                            ),
                          ],
                        ),
                      )
                      : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputRow(BuildContext context, ChatPalette palette, VoiceRecorderState recorder) {
    final recording = recorder.isRecording && (_holding || _locked);
    // The mic button stays the same widget the whole time, so the long-press
    // keeps tracking while the left side switches to the recording UI.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child:
                !recording
                    ? _textField(palette)
                    : _locked
                    ? _LockedRecordingBar(
                      key: const ValueKey('locked'),
                      state: recorder,
                      viewOnce: _voiceViewOnce,
                      onToggleViewOnce: () => setState(() => _voiceViewOnce = !_voiceViewOnce),
                      onDelete: _discardRecording,
                    )
                    : _HoldRecordingBar(key: const ValueKey('hold'), state: recorder, dragX: _dragX),
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // "Slide up to lock" hint above the mic while holding.
            if (recording && !_locked)
              Positioned(
                bottom: 62 - _dragY * 0.5,
                child: _LockHint(progress: (-_dragY / _lockDistance).clamp(0.0, 1.0)),
              ),
            Transform.translate(
              offset: Offset(_locked ? 0 : _dragX * 0.3, _locked ? 0 : _dragY * 0.3),
              child: AnimatedScale(
                scale: recording && !_locked ? 1.25 : 1,
                duration: const Duration(milliseconds: 150),
                child: _actionButton(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton() {
    final recording = _holding || _locked;
    final IconData icon;
    if (_locked) {
      icon = Icons.send_rounded;
    } else if (_hasText) {
      icon = widget.editing != null ? Icons.check_rounded : Icons.send_rounded;
    } else {
      icon = Icons.mic_rounded;
    }
    final circle = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: recording && !_locked ? null : AppColors.brandGradient,
        color: recording && !_locked ? AppColors.danger : null,
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder:
            (c, a) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(a),
              child: ScaleTransition(scale: a, child: c),
            ),
        child: Icon(icon, key: ValueKey(icon), color: Colors.white),
      ),
    );

    if (_hasText && !recording) {
      return Pressable(
        onTap: _send,
        onLongPress: widget.editing == null && widget.onSchedule != null ? _schedule : null,
        child: circle,
      );
    }
    if (_locked) return Pressable(onTap: _finishRecording, child: circle);
    // Mic: hold to record.
    return GestureDetector(
      onTap: _micHint,
      onLongPressStart: _onMicDown,
      onLongPressMoveUpdate: _onMicMove,
      onLongPressEnd: _onMicUp,
      child: circle,
    );
  }

  Widget _textField(ChatPalette palette) {
    return Container(
      key: const ValueKey('input'),
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(color: palette.surfaceHigh, borderRadius: BorderRadius.circular(26)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _toggleEmoji,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                _showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                key: ValueKey(_showEmoji),
                color: palette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              // WhatsApp-style formatting on selected text.
              contextMenuBuilder: _formattingMenu,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: tr('Message'),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: widget.onAttach,
                  icon: Transform.rotate(
                    angle: -0.6,
                    child: Icon(Icons.attach_file_rounded, color: palette.textSecondary),
                  ),
                ),
                // Send later (also: long-press the send button).
                if (_hasText && widget.onSchedule != null && widget.editing == null)
                  IconButton(
                    tooltip: tr('Send later'),
                    onPressed: _schedule,
                    icon: Icon(Icons.schedule_send_rounded, color: palette.textSecondary),
                  ),
                if (!_hasText)
                  IconButton(
                    onPressed: widget.onCamera,
                    icon: Icon(Icons.photo_camera_rounded, color: palette.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.title, required this.preview, required this.icon, required this.onClose});
  final String title;
  final String preview;
  final IconData icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: context.palette.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
        ],
      ),
    );
  }
}

/// While holding the mic: timer + "‹ Slide to cancel" that follows the finger.
class _HoldRecordingBar extends StatelessWidget {
  const _HoldRecordingBar({super.key, required this.state, required this.dragX});
  final VoiceRecorderState state;
  final double dragX;

  @override
  Widget build(BuildContext context) {
    final fade = (1 + dragX / 110).clamp(0.0, 1.0);
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: context.palette.surfaceHigh, borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          const _PulsingDot(),
          const SizedBox(width: 10),
          Text(
            Formatters.duration(state.elapsed),
            style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const Spacer(),
          Transform.translate(
            offset: Offset(dragX * 0.6, 0),
            child: Opacity(
              opacity: fade,
              child: Row(
                children: [
                  Icon(Icons.chevron_left_rounded, color: context.palette.textSecondary),
                  Text(tr('Slide to cancel'), style: TextStyle(color: context.palette.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Hands-free (locked) recording: delete, live waveform, view-once toggle.
class _LockedRecordingBar extends StatelessWidget {
  const _LockedRecordingBar({
    super.key,
    required this.state,
    required this.viewOnce,
    required this.onToggleViewOnce,
    required this.onDelete,
  });
  final VoiceRecorderState state;
  final bool viewOnce;
  final VoidCallback onToggleViewOnce;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final levels = state.levels.length > 34 ? state.levels.sublist(state.levels.length - 34) : state.levels;
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(color: context.palette.surfaceHigh, borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          IconButton(
            tooltip: tr('Delete'),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          ),
          const _PulsingDot(),
          const SizedBox(width: 8),
          Text(
            Formatters.duration(state.elapsed),
            style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final l in levels)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 60),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 2.5,
                    height: 3 + 28 * l,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                  ),
              ],
            ),
          ),
          // View once toggle ("1" in a circle).
          IconButton(
            tooltip: viewOnce ? tr('View once: on') : tr('View once: off'),
            onPressed: onToggleViewOnce,
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: viewOnce ? AppColors.primary : Colors.transparent,
                border: Border.all(color: viewOnce ? AppColors.primary : context.palette.textSecondary, width: 2),
              ),
              child: Text(
                '1',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: viewOnce ? Colors.white : context.palette.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Padlock bubble that fills as the finger slides up.
class _LockHint extends StatelessWidget {
  const _LockHint({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: context.palette.surfaceHigh,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          progress >= 1 ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 20,
          color: Color.lerp(context.palette.textSecondary, AppColors.primary, progress),
        ),
        const SizedBox(height: 4),
        Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: context.palette.textSecondary),
      ],
    ),
  );
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
    child: Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
    ),
  );
}

/// "Emoji | Stickers" switch at the top of the expression panel.
class _PanelTabs extends StatelessWidget {
  const _PanelTabs({required this.stickers, required this.onChanged});
  final bool stickers;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, IconData icon, bool value) {
      final selected = stickers == value;
      return Expanded(
        child: Pressable(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : context.palette.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? Colors.white : context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(60, 4, 60, 2),
      decoration: BoxDecoration(color: context.palette.surfaceHigh, borderRadius: BorderRadius.circular(17)),
      child: Row(
        children: [
          tab(tr('Emoji'), Icons.emoji_emotions_rounded, false),
          tab(tr('Stickers'), Icons.sticky_note_2_rounded, true),
        ],
      ),
    );
  }
}
