import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/entities/message_entity.dart';
import 'content/audio_content.dart';
import 'content/media_content.dart';
import 'content/poll_content.dart';
import 'stickers/sticker_catalog.dart';

class DeliveryTicks extends StatelessWidget {
  const DeliveryTicks({super.key, required this.status, this.color, this.readColor, this.size = 16});
  final DeliveryStatus status;
  final Color? color;

  /// Colour of the "read" double tick — must stand out from [color].
  final Color? readColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Colors.white.withValues(alpha: 0.75);
    final (icon, c) = switch (status) {
      DeliveryStatus.pending => (Icons.schedule_rounded, base),
      DeliveryStatus.sent => (Icons.done_rounded, base),
      DeliveryStatus.delivered => (Icons.done_all_rounded, base),
      DeliveryStatus.read => (Icons.done_all_rounded, readColor ?? AppColors.readTick),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Icon(icon, key: ValueKey(status), size: size, color: c),
    );
  }
}

/// A single message row: alignment, grouping, swipe-to-reply, reactions.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.myId,
    required this.participants,
    required this.isGroup,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.senderName,
    this.senderPhoto,
    required this.onReply,
    required this.onLongPress,
    required this.onReactionTap,
    this.onReplyTap,
    this.onPollVote,
    this.nameOf,
    this.onOpenViewOnce,
    this.onReview,
    this.isStarred = false,
  });

  /// Set for group admins: approve (true) / reject (false) pending media.
  final ValueChanged<bool>? onReview;
  final bool isStarred;

  final MessageEntity message;
  final String myId;
  final List<String> participants;
  final bool isGroup;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String senderName;
  final String? senderPhoto;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final VoidCallback onReactionTap;
  final VoidCallback? onReplyTap;
  final ValueChanged<List<String>>? onPollVote;
  final VoidCallback? onOpenViewOnce;
  final String Function(String uid)? nameOf;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _triggered = false;
  late final AnimationController _snapBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() => setState(() => _dragX = _dragStart * (1 - Curves.easeOut.transform(_snapBack.value))));
  double _dragStart = 0;

  static const _replyThreshold = 64.0;

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.message.deletedForEveryone) return;
    setState(() => _dragX = (_dragX + d.delta.dx).clamp(0.0, 96.0));
    if (!_triggered && _dragX >= _replyThreshold) {
      _triggered = true;
      HapticFeedback.lightImpact();
    } else if (_triggered && _dragX < _replyThreshold) {
      _triggered = false;
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_triggered) widget.onReply();
    _triggered = false;
    _dragStart = _dragX;
    _snapBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    if (m.type == MessageType.system) return _SystemChip(text: m.text);

    final isMine = m.isMine(widget.myId);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final showAvatar = widget.isGroup && !isMine;

    final bubble = _BubbleBody(
      message: m,
      isMine: isMine,
      participants: widget.participants,
      showSenderName: widget.isGroup && !isMine && widget.isFirstInGroup,
      senderName: widget.senderName,
      hasTail: widget.isLastInGroup,
      onReplyTap: widget.onReplyTap,
      myId: widget.myId,
      onPollVote: widget.onPollVote,
      nameOf: widget.nameOf,
      onOpenViewOnce: widget.onOpenViewOnce,
    );

    final withReactions =
        m.reactions.isEmpty
            ? bubble
            : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  bubble,
                  Positioned(
                    bottom: -16,
                    right: isMine ? 10 : null,
                    left: isMine ? null : 10,
                    child: _ReactionsChip(reactions: m.reactions, myId: widget.myId, onTap: widget.onReactionTap),
                  ),
                ],
              ),
            );

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Reply icon revealed while swiping.
          Positioned(
            left: 12,
            child: Opacity(
              opacity: (_dragX / _replyThreshold).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * (_dragX / _replyThreshold).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: context.palette.surfaceHigh, shape: BoxShape.circle),
                  child: Icon(Icons.reply_rounded, size: 20, color: context.colors.primary),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: Padding(
              padding: EdgeInsets.only(
                left: isMine ? 48 : 10,
                right: isMine ? 10 : 48,
                top: widget.isFirstInGroup ? 6 : 1.5,
                bottom: widget.isLastInGroup ? 4 : 1.5,
              ),
              child: Row(
                mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showAvatar) ...[
                    SizedBox(
                      width: 30,
                      child:
                          widget.isLastInGroup
                              ? AppAvatar(name: widget.senderName, imageUrl: widget.senderPhoto, size: 30)
                              : null,
                    ),
                    const SizedBox(width: 6),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        withReactions,
                        if (m.pendingApproval || m.rejected)
                          _ModerationStrip(message: m, isMine: isMine, onReview: widget.onReview),
                        if (widget.isStarred)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                            child: Icon(Icons.star_rounded, size: 14, color: context.palette.textSecondary),
                          ),
                      ],
                    ),
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

class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.message,
    required this.isMine,
    required this.participants,
    required this.showSenderName,
    required this.senderName,
    required this.hasTail,
    required this.myId,
    this.onReplyTap,
    this.onPollVote,
    this.nameOf,
    this.onOpenViewOnce,
  });

  final String myId;
  final ValueChanged<List<String>>? onPollVote;
  final VoidCallback? onOpenViewOnce;
  final String Function(String uid)? nameOf;
  final MessageEntity message;
  final bool isMine;
  final List<String> participants;
  final bool showSenderName;
  final String senderName;
  final bool hasTail;
  final VoidCallback? onReplyTap;

  bool get _isBare =>
      !message.deletedForEveryone &&
      (message.type == MessageType.sticker || (message.type == MessageType.text && _isEmojiOnly(message.text)));

  bool get _isVisualMedia =>
      !message.deletedForEveryone &&
      !message.viewOnce &&
      (message.type == MessageType.image || message.type == MessageType.video || message.type == MessageType.location);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: !isMine && hasTail ? tail : r,
      bottomRight: isMine && hasTail ? tail : r,
    );
    final fg = isMine ? palette.outgoingText : palette.incomingText;

    final meta = _Meta(message: message, isMine: isMine, participants: participants, color: fg.withValues(alpha: 0.7));

    final content = <Widget>[
      if (showSenderName)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
          child: Text(
            senderName,
            style: TextStyle(color: AppColors.identity(senderName), fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      if (message.isForwarded && !message.deletedForEveryone)
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 4, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.isFrequentlyForwarded ? Icons.fast_forward_rounded : Icons.shortcut_rounded,
                size: 14,
                color: fg.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 4),
              Text(
                message.isFrequentlyForwarded ? tr('Forwarded many times') : tr('Forwarded'),
                style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      if (message.replyTo != null && !message.deletedForEveryone)
        _QuotedReply(reply: message.replyTo!, isMine: isMine, onTap: onReplyTap),
      _content(context, fg, meta),
    ];

    // Stickers and short emoji-only texts float on the wallpaper, no bubble.
    if (_isBare) {
      final textColor = palette.incomingText;
      return Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSenderName)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
              child: Text(
                senderName,
                style: TextStyle(color: AppColors.identity(senderName), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          if (message.replyTo != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: DecoratedBox(
                decoration: BoxDecoration(color: palette.incomingBubble, borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: _QuotedReply(reply: message.replyTo!, isMine: false, onTap: onReplyTap),
                ),
              ),
            ),
          if (message.type == MessageType.sticker)
            _StickerContent(message: message)
          else
            _LinkifiedText(text: message.text, color: textColor, isEmojiOnly: true),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: palette.incomingBubble.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _Meta(
              message: message,
              isMine: isMine,
              participants: participants,
              color: palette.textSecondary,
              readColor: AppColors.primary,
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isMine ? AppColors.outgoingBubbleGradient : null,
        color: isMine ? null : palette.incomingBubble,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: (isMine ? AppColors.primary : Colors.black).withValues(alpha: context.isDark ? 0.18 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: _isVisualMedia ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(10, 7, 10, 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: content),
      ),
    );
  }

  Widget _content(BuildContext context, Color fg, Widget meta) {
    if (message.deletedForEveryone) {
      return _TextWithMeta(
        meta: meta,
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.block_rounded, size: 15, color: fg.withValues(alpha: 0.6)),
              ),
              TextSpan(
                text: tr('  This message was deleted'),
                style: TextStyle(color: fg.withValues(alpha: 0.7), fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    if (message.viewOnce) {
      return _ViewOnceContent(message: message, isMine: isMine, myId: myId, fg: fg, meta: meta, onOpen: onOpenViewOnce);
    }

    switch (message.type) {
      case MessageType.sticker:
        return _StickerContent(message: message);
      case MessageType.poll:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            PollContent(
              message: message,
              myId: myId,
              isMine: isMine,
              onVote: onPollVote ?? (_) {},
              nameOf: nameOf ?? (uid) => uid,
            ),
            meta,
          ],
        );
      case MessageType.text:
      case MessageType.system:
        return _TextWithMeta(
          meta: meta,
          child: _LinkifiedText(text: message.text, color: fg, isEmojiOnly: _isEmojiOnly(message.text)),
        );
      case MessageType.image:
      case MessageType.video:
      case MessageType.location:
        final media = switch (message.type) {
          MessageType.image => ImageContent(message: message),
          MessageType.video => VideoContent(message: message),
          _ => LocationContent(message: message, isMine: isMine),
        };
        final hasCaption = message.text.isNotEmpty && message.type != MessageType.location;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                media,
                if (!hasCaption)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _Meta(
                        message: message,
                        isMine: isMine,
                        participants: participants,
                        color: Colors.white,
                        readColor: AppColors.readTickOnDark,
                      ),
                    ),
                  ),
              ],
            ),
            if (hasCaption)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                child: _TextWithMeta(meta: meta, child: _LinkifiedText(text: message.text, color: fg)),
              ),
          ],
        );
      case MessageType.audio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [AudioContent(message: message, isMine: isMine), meta],
        );
      case MessageType.file:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            FileContent(message: message, isMine: isMine),
            const SizedBox(height: 4),
            if (message.text.isNotEmpty)
              _TextWithMeta(meta: meta, child: _LinkifiedText(text: message.text, color: fg))
            else
              meta,
          ],
        );
    }
  }

  static bool _isEmojiOnly(String text) {
    final t = text.trim();
    if (t.isEmpty || t.runes.length > 6) return false;
    return RegExp(r'^(\p{Extended_Pictographic}|\p{Emoji_Component}|‍|️|\s)+$', unicode: true).hasMatch(t);
  }
}

/// Puts time/ticks on the same line as short text, or wraps them neatly
/// under long text — never overlapping.
class _TextWithMeta extends StatelessWidget {
  const _TextWithMeta({required this.child, required this.meta});
  final Widget child;
  final Widget meta;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [child, Padding(padding: const EdgeInsets.only(top: 2), child: meta)],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.message,
    required this.isMine,
    required this.participants,
    required this.color,
    this.readColor = AppColors.readTick,
  });
  final Color readColor;
  final MessageEntity message;
  final bool isMine;
  final List<String> participants;
  final Color color;

  /// With my read receipts off (1:1 chats), "read" is shown as "delivered".
  DeliveryStatus _status(BuildContext context) {
    final st = message.statusFor(participants);
    if (st == DeliveryStatus.read && !ReadReceiptsScope.enabledOf(context)) return DeliveryStatus.delivered;
    return st;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited && !message.deletedForEveryone)
          Text(tr('edited  '), style: TextStyle(color: color, fontSize: 10.5, fontStyle: FontStyle.italic)),
        Text(Formatters.messageTime(message.createdAt), style: TextStyle(color: color, fontSize: 10.5)),
        if (isMine && !message.deletedForEveryone) ...[
          const SizedBox(width: 3),
          DeliveryTicks(status: _status(context), color: color, readColor: readColor, size: 15),
        ],
      ],
    );
  }
}

/// Message text with tappable links. Group invite links open the in-app
/// join screen; everything else opens in the browser.
class _LinkifiedText extends StatefulWidget {
  const _LinkifiedText({required this.text, required this.color, this.isEmojiOnly = false});
  final String text;
  final Color color;
  final bool isEmojiOnly;

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  static final _url = RegExp(r'(https?:\/\/[^\s]+)');
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _open(String url) {
    final join = GroupLinks.parse(url);
    if (join != null && url.contains(GroupLinks.host)) {
      context.push(AppRoutes.joinGroup(join.$1, join.$2));
      return;
    }
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final base = TextStyle(color: widget.color, fontSize: widget.isEmojiOnly ? 40 : 15.5, height: 1.35);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _url.allMatches(text)) {
      if (match.start > last) spans.addAll(formattedSpans(text.substring(last, match.start)));
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          recognizer: recognizer,
          style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
        ),
      );
      last = match.end;
    }
    if (last < text.length) spans.addAll(formattedSpans(text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// WhatsApp-style formatting: *bold*, _italic_, ~strikethrough~, ```monospace```.
final _formatRe = RegExp(r'```([\s\S]+?)```|\*([^*\n]+)\*|_([^_\n]+)_|~([^~\n]+)~');

List<InlineSpan> formattedSpans(String text) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _formatRe.allMatches(text)) {
    // Markers must not sit inside a word (e.g. snake_case_names stay as is).
    final before = m.start == 0 ? ' ' : text[m.start - 1];
    final after = m.end >= text.length ? ' ' : text[m.end];
    if (RegExp(r'[A-Za-z0-9؀-ۿ]').hasMatch(before) || RegExp(r'[A-Za-z0-9؀-ۿ]').hasMatch(after)) {
      continue;
    }
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    final TextStyle style;
    final String inner;
    if (m.group(1) != null) {
      inner = m.group(1)!;
      style = const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Courier', 'monospace']);
    } else if (m.group(2) != null) {
      inner = m.group(2)!;
      style = const TextStyle(fontWeight: FontWeight.w800);
    } else if (m.group(3) != null) {
      inner = m.group(3)!;
      style = const TextStyle(fontStyle: FontStyle.italic);
    } else {
      inner = m.group(4)!;
      style = const TextStyle(decoration: TextDecoration.lineThrough);
    }
    spans.add(TextSpan(text: inner, style: style));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

class _QuotedReply extends StatelessWidget {
  const _QuotedReply({required this.reply, required this.isMine, this.onTap});
  final ReplyInfo reply;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isMine ? Colors.white : AppColors.identity(reply.senderName);
    final fg = isMine ? Colors.white : context.palette.incomingText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: isMine ? Colors.white.withValues(alpha: 0.16) : context.palette.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accent, width: 3.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reply.senderName, style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(
              reply.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionsChip extends StatelessWidget {
  const _ReactionsChip({required this.reactions, required this.myId, required this.onTap});
  final Map<String, String> reactions;
  final String myId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final e in reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    final mine = reactions.containsKey(myId);
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        builder: (_, s, c) => Transform.scale(scale: s, child: c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: context.palette.incomingBubble,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: mine ? AppColors.primary.withValues(alpha: 0.6) : context.theme.scaffoldBackgroundColor,
              width: 2,
            ),
          ),
          child: Text(
            [...counts.keys.take(3), if (reactions.length > 1) ' ${reactions.length}'].join(),
            style: TextStyle(fontSize: 14, color: context.palette.incomingText),
          ),
        ),
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  const _SystemChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.surfaceHigh.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Floating day separator ("Today", "Yesterday", …).
class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.surfaceHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: Text(
          Formatters.dayHeader(date),
          style: TextStyle(color: context.palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Built-in sticker (drawn in code) or a custom sticker image.
class _StickerContent extends StatelessWidget {
  const _StickerContent({required this.message});
  final MessageEntity message;

  static const _size = 150.0;

  @override
  Widget build(BuildContext context) {
    final def = StickerCatalog.byId(message.stickerId);
    if (def != null) return StickerView(sticker: def, size: _size);
    final url = message.mediaUrl;
    if (url == null) {
      return const SizedBox(
        width: _size,
        height: _size,
        child: Center(child: Text('💟', style: TextStyle(fontSize: 64))),
      );
    }
    return SizedBox(
      width: _size,
      height: _size,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48),
      ),
    );
  }
}

/// Whether blue ticks are shown in this chat (off when the user disabled read
/// receipts, in 1:1 chats — same as WhatsApp).
class ReadReceiptsScope extends InheritedWidget {
  const ReadReceiptsScope({super.key, required this.enabled, required super.child});
  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadReceiptsScope>()?.enabled ?? true;

  @override
  bool updateShouldNotify(ReadReceiptsScope old) => old.enabled != enabled;
}

/// "① Photo" / "① Voice message": opens once, then shows "Opened".
class _ViewOnceContent extends StatelessWidget {
  const _ViewOnceContent({
    required this.message,
    required this.isMine,
    required this.myId,
    required this.fg,
    required this.meta,
    this.onOpen,
  });

  final MessageEntity message;
  final bool isMine;
  final String myId;
  final Color fg;
  final Widget meta;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isAudio = message.type == MessageType.audio;
    final label = isAudio ? tr('Voice message') : tr('Photo');
    // Everyone — the sender too — can open it exactly once.
    final opened = message.openedByUser(myId);
    final canOpen = !opened && message.mediaUrl != null;
    final seenByOthers = isMine && message.openedBy.any((u) => u != myId);

    return InkWell(
      onTap: canOpen ? onOpen : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: fg.withValues(alpha: opened ? 0.4 : 0.9), width: 2, style: BorderStyle.solid),
              ),
              child: Text(
                '1',
                style: TextStyle(color: fg.withValues(alpha: opened ? 0.5 : 1), fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    opened ? tr('Opened') : label,
                    style: TextStyle(
                      color: fg.withValues(alpha: opened ? 0.6 : 1),
                      fontWeight: FontWeight.w600,
                      fontStyle: opened ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  if (canOpen)
                    Text(
                      tr('Tap to open — view once'),
                      style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11.5),
                    ),
                  if (seenByOthers)
                    Text(tr('Seen'), style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            meta,
          ],
        ),
      ),
    );
  }
}

/// Under media from an anonymous member: status for the sender, decision
/// buttons for admins.
class _ModerationStrip extends StatelessWidget {
  const _ModerationStrip({required this.message, required this.isMine, this.onReview});
  final MessageEntity message;
  final bool isMine;
  final ValueChanged<bool>? onReview;

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.palette.textSecondary, fontSize: 12);
    if (message.rejected) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(tr('🚫 Not approved by an admin — only you can see this'), style: secondary),
      );
    }
    if (isMine || onReview == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(tr('⏳ Waiting for an admin to approve'), style: secondary),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(color: context.palette.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(tr('Anonymous member — share with the group?'), style: secondary)),
          TextButton(
            onPressed: () => onReview!(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(tr('Reject')),
          ),
          FilledButton(onPressed: () => onReview!(true), child: Text(tr('Approve'))),
        ],
      ),
    );
  }
}
