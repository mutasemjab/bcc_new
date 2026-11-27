import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../bloc/conversation/conversation_bloc.dart';

/// Outgoing placeholder shown while a media file uploads.
class UploadBubble extends StatelessWidget {
  const UploadBubble({super.key, required this.upload});
  final PendingUpload upload;

  @override
  Widget build(BuildContext context) {
    final isImage = upload.type == MessageType.image;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(48, 4, 10, 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(gradient: AppColors.outgoingBubbleGradient, borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: isImage ? 220 : 240,
            height: isImage ? 220 : 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isImage)
                  Image.file(File(upload.localPath), fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.white.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(_icon(upload.type), color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            upload.fileName ?? _label(upload.type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isImage) Container(color: Colors.black.withValues(alpha: 0.35)),
                Align(
                  alignment: isImage ? Alignment.center : Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: isImage ? 0 : 12),
                    child: SizedBox(
                      width: isImage ? 54 : 30,
                      height: isImage ? 54 : 30,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: upload.progress),
                        duration: const Duration(milliseconds: 250),
                        builder:
                            (_, v, __) => CircularProgressIndicator(
                              value: v == 0 ? null : v,
                              strokeWidth: 3,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(MessageType t) => switch (t) {
    MessageType.video => Icons.videocam_rounded,
    MessageType.audio => Icons.mic_rounded,
    _ => Icons.insert_drive_file_rounded,
  };

  static String _label(MessageType t) => switch (t) {
    MessageType.video => tr('Sending video…'),
    MessageType.audio => tr('Sending voice message…'),
    _ => tr('Sending file…'),
  };
}
