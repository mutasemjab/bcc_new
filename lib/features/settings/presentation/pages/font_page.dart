import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/appearance_settings.dart';

/// Settings → Font: app font family + text size, with a live preview.
class FontPage extends StatelessWidget {
  const FontPage({super.key});

  @override
  Widget build(BuildContext context) {
    final look = sl<AppearanceSettings>();
    return ListenableBuilder(
      listenable: look,
      builder:
          (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Font')),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.palette.surfaceHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Hello! How are you today? 👋\nمرحبا! كيف حالك اليوم؟\n*Bold*  _italic_  ~strike~',
                    style: GoogleFonts.getFont(look.font, fontSize: 16 * look.scale, height: 1.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('TEXT SIZE', style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<double>(
                    segments: [
                      for (final (v, label) in AppearanceSettings.sizes) ButtonSegment(value: v, label: Text(label)),
                    ],
                    selected: {look.scale},
                    onSelectionChanged: (v) => look.setScale(v.first),
                    showSelectedIcon: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('FONT', style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                for (final f in AppearanceSettings.fonts)
                  ListTile(
                    title: Text(f.label, style: GoogleFonts.getFont(f.family, fontSize: 17)),
                    subtitle: Text('Aa Bb 123 — أ ب ت', style: GoogleFonts.getFont(f.family)),
                    trailing:
                        look.font == f.family ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                    onTap: () => look.setFont(f.family),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Tip: in a message, select text to make it bold, italic, strikethrough or monospace — '
                    'or type *bold*, _italic_, ~strike~ or ```code```.',
                    style: TextStyle(color: context.palette.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
