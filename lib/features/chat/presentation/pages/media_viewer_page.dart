import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen, pinch-to-zoom image viewer with hero transition.
class MediaViewerPage extends StatelessWidget {
  const MediaViewerPage({super.key, required this.url, required this.heroTag, this.caption});
  final String url;
  final Object heroTag;
  final String? caption;

  static Future<void> open(BuildContext context, {required String url, required Object heroTag, String? caption}) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => MediaViewerPage(url: url, heroTag: heroTag, caption: caption),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0).abs() > 600) Navigator.pop(context);
              },
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Hero(tag: heroTag, child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain))),
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(caption!, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.url});
  final String url;

  static Future<void> open(BuildContext context, String url) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VideoPlayerPage(url: url)));

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Center(
          child:
              !_ready
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: IconButton.filled(
                          iconSize: 44,
                          style: IconButton.styleFrom(backgroundColor: Colors.white24),
                          onPressed: () => _c.value.isPlaying ? _c.pause() : _c.play(),
                          icon: Icon(
                            _c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: VideoProgressIndicator(_c, allowScrubbing: true, padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
