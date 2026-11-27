import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/di.dart';
import '../../../../../core/services/media_picker_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/pressable.dart';
import 'my_stickers_store.dart';
import 'sticker_catalog.dart';

/// Sticker keyboard: "My stickers" (own images) + the built-in packs.
class StickerPanel extends StatefulWidget {
  const StickerPanel({super.key, required this.onSticker, required this.onCustomSticker});
  final ValueChanged<String> onSticker;
  final ValueChanged<File> onCustomSticker;

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel> {
  final _store = sl<MyStickersStore>();
  late List<File> _mine = _store.load();
  int _tab = 1; // open on the first built-in pack

  Future<void> _addSticker() async {
    final f = await sl<MediaPickerService>().pickImage();
    if (f == null) return;
    final list = await _store.add(f);
    if (mounted) setState(() => _mine = list);
  }

  Future<void> _removeSticker(File f) async {
    final list = await _store.remove(f);
    if (mounted) setState(() => _mine = list);
  }

  @override
  Widget build(BuildContext context) {
    final packs = StickerCatalog.packs;
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _TabChip(
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
                child: Icon(Icons.collections_rounded, size: 20, color: _tab == 0 ? AppColors.primary : null),
              ),
              for (final (i, p) in packs.indexed)
                _TabChip(
                  selected: _tab == i + 1,
                  onTap: () => setState(() => _tab = i + 1),
                  child: Text('${p.icon} ${p.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        Expanded(child: _tab == 0 ? _mineGrid(context) : _packGrid(packs[_tab - 1])),
      ],
    );
  }

  Widget _packGrid(StickerPack pack) => GridView.builder(
    padding: const EdgeInsets.all(10),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
    ),
    itemCount: pack.stickers.length,
    itemBuilder: (_, i) {
      final s = pack.stickers[i];
      return Pressable(
        scale: 0.9,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onSticker(s.id);
        },
        child: FittedBox(child: StickerView(sticker: s, size: 120)),
      );
    },
  );

  Widget _mineGrid(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(10),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemCount: _mine.length + 1,
    itemBuilder: (_, i) {
      if (i == 0) {
        return Pressable(
          onTap: _addSticker,
          child: Container(
            decoration: BoxDecoration(
              color: context.palette.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
                SizedBox(height: 4),
                Text(tr('Add'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }
      final f = _mine[i - 1];
      return Pressable(
        scale: 0.9,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onCustomSticker(f);
        },
        onLongPress: () async {
          HapticFeedback.mediumImpact();
          final remove = await showModalBottomSheet<bool>(
            context: context,
            builder:
                (ctx) => SafeArea(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: Text(tr('Remove from my stickers'), style: TextStyle(color: AppColors.danger)),
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
          );
          if (remove == true) await _removeSticker(f);
        },
        child: Image.file(f, fit: BoxFit.contain),
      );
    },
  );
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : context.palette.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    ),
  );
}
