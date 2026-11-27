import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/di.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/services/wallpaper_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/chat_wallpaper.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/pressable.dart';

/// Pick a chat wallpaper with a live preview. With [chatId] the user can
/// apply it to that chat only or to all chats.
class WallpaperPage extends StatefulWidget {
  const WallpaperPage({super.key, this.chatId});
  final String? chatId;

  @override
  State<WallpaperPage> createState() => _WallpaperPageState();
}

class _WallpaperPageState extends State<WallpaperPage> {
  final _store = sl<WallpaperStore>();
  late Wallpaper _selected = _store.forChat(widget.chatId);

  static const _colors = [
    Color(0xFFE8F3FA),
    Color(0xFFD6ECF8),
    Color(0xFF84C4EB),
    Color(0xFF3A9AD9),
    Color(0xFFE9E4D4),
    Color(0xFFF6E7D8),
    Color(0xFFFDE2E4),
    Color(0xFFE2F0CB),
    Color(0xFFCDEBD7),
    Color(0xFFD9D7F1),
    Color(0xFFEDEDED),
    Color(0xFF5A5A5C),
    Color(0xFF2B2B2D),
    Color(0xFF1E3A4C),
    Color(0xFF3E2C41),
  ];

  Future<void> _pickPhoto() async {
    final f = await sl<MediaPickerService>().pickImage();
    if (f == null) return;
    final path = await _store.keepImage(f);
    if (mounted) setState(() => _selected = Wallpaper.image(path));
  }

  Future<void> _apply() async {
    String? target = widget.chatId;
    if (widget.chatId != null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder:
            (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.chat_rounded),
                    title: Text(tr('For this chat')),
                    onTap: () => Navigator.pop(ctx, 'chat'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.forum_rounded),
                    title: Text(tr('For all chats')),
                    onTap: () => Navigator.pop(ctx, 'all'),
                  ),
                ],
              ),
            ),
      );
      if (choice == null) return;
      target = choice == 'chat' ? widget.chatId : null;
      if (choice == 'all') await _store.clearOverride(widget.chatId!);
    }
    await _store.set(_selected, chatId: target);
    if (!mounted) return;
    AppFeedback.info(context, tr('Wallpaper set'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasOverride = widget.chatId != null && _store.hasOverride(widget.chatId!);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Chat wallpaper')),
        actions: [
          if (hasOverride)
            TextButton(
              onPressed: () async {
                await _store.clearOverride(widget.chatId!);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(tr('Reset')),
            ),
        ],
      ),
      body: Column(
        children: [
          // Live preview
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.fromLTRB(60, 8, 60, 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.palette.stroke, width: 2),
              ),
              child: ChatWallpaper(
                preview: _selected,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _PreviewBubble(text: tr('Hey! How do I look? 😄'), mine: false),
                      _PreviewBubble(text: tr('Looking great 👌'), mine: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: GridView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              children: [
                _Swatch(
                  selected: _selected.kind == WallpaperKind.pattern,
                  onTap: () => setState(() => _selected = const Wallpaper.pattern()),
                  child: ChatWallpaper(preview: Wallpaper.pattern(), child: Center(child: Text(tr('Default')))),
                ),
                _Swatch(
                  selected: _selected.kind == WallpaperKind.image,
                  onTap: _pickPhoto,
                  child:
                      _selected.kind == WallpaperKind.image
                          ? Image.file(File(_selected.imagePath!), fit: BoxFit.cover)
                          : Container(
                            color: context.palette.surfaceHigh,
                            child: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
                          ),
                ),
                for (final c in _colors)
                  _Swatch(
                    selected: _selected.kind == WallpaperKind.color && _selected.color == c,
                    onTap: () => setState(() => _selected = Wallpaper.color(c)),
                    child: ColoredBox(color: c),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: GradientButton(label: tr('Set wallpaper'), icon: Icons.wallpaper_rounded, onPressed: _apply),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.primary : context.palette.stroke, width: selected ? 3 : 1),
      ),
      child: DefaultTextStyle(style: const TextStyle(fontSize: 10, color: Colors.black54), child: child),
    ),
  );
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.text, required this.mine});
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: mine ? AppColors.outgoingBubbleGradient : null,
        color: mine ? null : context.palette.incomingBubble,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: TextStyle(color: mine ? Colors.white : context.palette.incomingText, fontSize: 13)),
    ),
  );
}
