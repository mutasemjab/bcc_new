import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';

/// What the user decided on the preview screen.
class PhotoSendResult {
  const PhotoSendResult({required this.files, required this.caption, required this.viewOnce});
  final List<File> files;
  final String caption;
  final bool viewOnce;
}

/// WhatsApp-style preview before sending photos: caption, view once, and for
/// a single photo — draw, add text and rotate. Returns null if cancelled.
Future<PhotoSendResult?> openPhotoPreview(
  BuildContext context,
  List<File> files, {
  bool allowViewOnce = true,
  bool viewOnce = false,
}) {
  if (files.isEmpty) return Future.value(null);
  return Navigator.of(context).push<PhotoSendResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PhotoPreviewPage(files: files, allowViewOnce: allowViewOnce, viewOnce: viewOnce),
    ),
  );
}

class _Stroke {
  _Stroke(this.color, this.width);
  final Color color;
  final double width;
  final points = <Offset>[];
}

class _TextLayer {
  _TextLayer(this.text, this.color, this.offset);
  final String text;
  final Color color;
  Offset offset;
}

class _PhotoPreviewPage extends StatefulWidget {
  const _PhotoPreviewPage({required this.files, required this.allowViewOnce, required this.viewOnce});
  final List<File> files;
  final bool allowViewOnce;
  final bool viewOnce;

  @override
  State<_PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<_PhotoPreviewPage> {
  static const _colors = [
    Colors.white,
    Colors.black,
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF3A9AD9),
    Color(0xFFAF52DE),
  ];

  final _caption = TextEditingController();
  final _boundary = GlobalKey();
  late bool _viewOnce = widget.viewOnce;
  int _page = 0;

  // Editing (single photo only).
  bool _drawing = false;
  Color _color = const Color(0xFFFF3B30);
  int _quarterTurns = 0;
  final _strokes = <_Stroke>[];
  final _texts = <_TextLayer>[];
  bool _sending = false;

  bool get _single => widget.files.length == 1;
  bool get _edited => _strokes.isNotEmpty || _texts.isNotEmpty || _quarterTurns % 4 != 0;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _addText() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(tr('Add text')),
            content: TextField(controller: controller, autofocus: true, maxLines: 3, minLines: 1),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(tr('Add'))),
            ],
          ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final size = _boundary.currentContext?.size ?? const Size(300, 300);
    setState(() => _texts.add(_TextLayer(text, _color, Offset(size.width / 2 - 60, size.height / 2 - 20))));
  }

  void _undo() {
    setState(() {
      if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      } else if (_texts.isNotEmpty) {
        _texts.removeLast();
      }
    });
  }

  /// Renders the edited photo (drawings, text, rotation) into a new file.
  Future<File> _export() async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ratio = (MediaQuery.devicePixelRatioOf(context) * 1.5).clamp(2.0, 4.0);
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final out = File(tr('{0}/edited_{1}.png', [dir.path, DateTime.now().millisecondsSinceEpoch]));
    await out.writeAsBytes(bytes!.buffer.asUint8List());
    return out;
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final files = _single && _edited ? [await _export()] : widget.files;
    if (!mounted) return;
    Navigator.pop(context, PhotoSendResult(files: files, caption: _caption.text.trim(), viewOnce: _viewOnce));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: const CloseButton(),
        title: widget.files.length > 1 ? Text('${_page + 1} / ${widget.files.length}') : null,
        actions: [
          if (_single) ...[
            if (_strokes.isNotEmpty || _texts.isNotEmpty)
              IconButton(tooltip: tr('Undo'), onPressed: _undo, icon: const Icon(Icons.undo_rounded)),
            IconButton(
              tooltip: tr('Rotate'),
              onPressed: () => setState(() => _quarterTurns++),
              icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
            ),
            IconButton(tooltip: tr('Text'), onPressed: _addText, icon: const Icon(Icons.text_fields_rounded)),
            IconButton(
              tooltip: tr('Draw'),
              onPressed: () => setState(() => _drawing = !_drawing),
              icon: Icon(Icons.edit_rounded, color: _drawing ? _color : Colors.white),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_single && _drawing)
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in _colors)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? Colors.white : Colors.white24,
                            width: _color == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child:
                _single
                    ? Center(child: _editableImage())
                    : PageView.builder(
                      itemCount: widget.files.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => InteractiveViewer(child: Center(child: Image.file(widget.files[i]))),
                    ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      style: const TextStyle(color: Colors.white),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: tr('Add a caption…'),
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon:
                            widget.allowViewOnce
                                ? IconButton(
                                  tooltip: _viewOnce ? tr('View once: on') : tr('View once: off'),
                                  onPressed: () => setState(() => _viewOnce = !_viewOnce),
                                  icon: Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _viewOnce ? AppColors.primary : Colors.transparent,
                                      border: Border.all(
                                        color: _viewOnce ? AppColors.primary : Colors.white70,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Text(
                                      '1',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ),
                                )
                                : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                      child:
                          _sending
                              ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                              : const Icon(Icons.send_rounded, color: Colors.white),
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

  /// Photo + drawing + text layers, captured as one image on send.
  Widget _editableImage() {
    return RepaintBoundary(
      key: _boundary,
      child: RotatedBox(
        quarterTurns: _quarterTurns % 4,
        child: Stack(
          children: [
            Image.file(widget.files.first, fit: BoxFit.contain),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart:
                    _drawing
                        ? (d) => setState(() => _strokes.add(_Stroke(_color, 5)..points.add(d.localPosition)))
                        : null,
                onPanUpdate: _drawing ? (d) => setState(() => _strokes.last.points.add(d.localPosition)) : null,
                child: CustomPaint(painter: _StrokePainter(_strokes)),
              ),
            ),
            for (final t in _texts)
              Positioned(
                left: t.offset.dx,
                top: t.offset.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() => t.offset += d.delta),
                  onLongPress: () => setState(() => _texts.remove(t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.color == Colors.white ? Colors.black45 : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t.text, style: TextStyle(color: t.color, fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint =
          Paint()
            ..color = s.color
            ..strokeWidth = s.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, s.width / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}
