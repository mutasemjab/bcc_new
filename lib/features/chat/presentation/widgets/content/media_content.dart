import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../domain/entities/message_entity.dart';
import '../../pages/media_viewer_page.dart';

const _mediaRadius = 16.0;

class ImageContent extends StatelessWidget {
  const ImageContent({super.key, required this.message});
  final MessageEntity message;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => MediaViewerPage.open(context, url: url, heroTag: message.id, caption: message.text),
      child: Hero(
        tag: message.id,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_mediaRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320, minWidth: 160, minHeight: 120),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder:
                  (_, __) => Container(
                    width: 240,
                    height: 240,
                    color: context.palette.surfaceHigh,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
              errorWidget:
                  (_, __, ___) => Container(
                    width: 240,
                    height: 180,
                    color: context.palette.surfaceHigh,
                    child: const Icon(Icons.broken_image_rounded),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class VideoContent extends StatelessWidget {
  const VideoContent({super.key, required this.message});
  final MessageEntity message;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    return GestureDetector(
      onTap: url == null ? null : () => VideoPlayerPage.open(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_mediaRadius),
        child: Container(
          width: 240,
          height: 170,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF23262B), Color(0xFF0E0F11)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.movie_creation_outlined, size: 90, color: Colors.white.withValues(alpha: 0.06)),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      message.fileSize == null ? tr('Video') : Formatters.fileSize(message.fileSize!),
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FileContent extends StatelessWidget {
  const FileContent({super.key, required this.message, required this.isMine});
  final MessageEntity message;
  final bool isMine;

  static (IconData, Color) _iconFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => (Icons.picture_as_pdf_rounded, const Color(0xFFFF4D6D)),
      'doc' || 'docx' => (Icons.description_rounded, const Color(0xFF2F7BFF)),
      'xls' || 'xlsx' || 'csv' => (Icons.table_chart_rounded, const Color(0xFF1FAA59)),
      'ppt' || 'pptx' => (Icons.slideshow_rounded, const Color(0xFFFF8A3D)),
      'zip' || 'rar' || '7z' => (Icons.folder_zip_rounded, const Color(0xFFE6B800)),
      'mp3' || 'wav' || 'm4a' => (Icons.audio_file_rounded, const Color(0xFF7B61FF)),
      _ => (Icons.insert_drive_file_rounded, AppColors.accent),
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = message.fileName ?? tr('Document');
    final (icon, color) = _iconFor(name);
    final fg = isMine ? Colors.white : context.palette.incomingText;
    return GestureDetector(
      onTap:
          message.mediaUrl == null
              ? null
              : () => launchUrl(Uri.parse(message.mediaUrl!), mode: LaunchMode.externalApplication),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMine ? Colors.white.withValues(alpha: 0.14) : context.palette.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (message.fileSize != null) Formatters.fileSize(message.fileSize!),
                      name.split('.').last.toUpperCase(),
                    ].join(' • '),
                    style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_rounded, color: fg.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class LocationContent extends StatelessWidget {
  const LocationContent({super.key, required this.message, required this.isMine});
  final MessageEntity message;
  final bool isMine;

  Future<void> _open() async {
    final lat = message.latitude, lng = message.longitude;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final lat = message.latitude, lng = message.longitude;
    if (lat == null || lng == null) return const SizedBox.shrink();
    final point = LatLng(lat, lng);
    return GestureDetector(
      // The map preview ignores touches, so catch taps over the whole card.
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_mediaRadius),
        child: SizedBox(
          width: 250,
          height: 170,
          child: Stack(
            children: [
              // Non-interactive OpenStreetMap preview (no API key needed).
              IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(initialCenter: point, initialZoom: 15.5),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bccchat.ammar',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on_rounded, color: AppColors.danger, size: 44),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.near_me_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        tr('Shared location'),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Spacer(),
                      Text(
                        tr('Open'),
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
