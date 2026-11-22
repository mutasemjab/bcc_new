import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable.dart';
import '../bloc/status_bloc.dart';

/// Full-screen text story composer with colour + font cycling.
class TextStatusEditorPage extends StatefulWidget {
  const TextStatusEditorPage({super.key});
  @override
  State<TextStatusEditorPage> createState() => _TextStatusEditorPageState();
}

class _TextStatusEditorPageState extends State<TextStatusEditorPage> {
  final _controller = TextEditingController();
  int _colorIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _post() {
    if (_controller.text.trim().isEmpty) return;
    context.read<StatusBloc>().add(
      TextStatusPosted(_controller.text, AppColors.storyBackgrounds[_colorIndex].toARGB32()),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.storyBackgrounds[_colorIndex];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        color: color,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            leading: const CloseButton(color: Colors.white),
            actions: [
              IconButton(
                tooltip: 'Background',
                onPressed: () => setState(() => _colorIndex = (_colorIndex + 1) % AppColors.storyBackgrounds.length),
                icon: const Icon(Icons.palette_rounded, color: Colors.white),
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                maxLength: 700,
                textAlign: TextAlign.center,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, height: 1.3),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  hintText: 'Type a status',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 30, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          floatingActionButton: _SendFab(onTap: _post),
        ),
      ),
    );
  }
}

/// Preview a picked photo and add a caption before sharing.
class ImageStatusEditorPage extends StatefulWidget {
  const ImageStatusEditorPage({super.key, required this.image});
  final File image;
  @override
  State<ImageStatusEditorPage> createState() => _ImageStatusEditorPageState();
}

class _ImageStatusEditorPageState extends State<ImageStatusEditorPage> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, leading: const CloseButton(color: Colors.white)),
        body: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(child: Image.file(widget.image, fit: BoxFit.contain)),
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption…',
                        hintStyle: const TextStyle(color: Colors.white60),
                        fillColor: Colors.white.withValues(alpha: 0.14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SendFab(
                    onTap: () {
                      context.read<StatusBloc>().add(ImageStatusPosted(widget.image, _caption.text));
                      Navigator.of(context).pop();
                    },
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

class _SendFab extends StatelessWidget {
  const _SendFab({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: const Icon(Icons.send_rounded, color: Colors.white),
    ),
  );
}
