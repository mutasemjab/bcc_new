import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/chat_extras.dart';
import 'media_viewer_page.dart';

/// "Media, links and docs" for a chat — like WhatsApp's contact/group info.
class ChatMediaPage extends StatefulWidget {
  const ChatMediaPage({super.key, required this.chatId});
  final String chatId;

  @override
  State<ChatMediaPage> createState() => _ChatMediaPageState();
}

class _LinkItem {
  const _LinkItem(this.url, this.message);
  final String url;
  final MessageEntity message;
}

class _ChatMediaPageState extends State<ChatMediaPage> {
  static final _urlRe = RegExp(r'https?:\/\/[^\s]+');

  bool _loading = true;
  String? _error;
  List<MessageEntity> _media = const [];
  List<MessageEntity> _docs = const [];
  List<_LinkItem> _links = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionBloc>().state;
    final me = session is SessionAuthenticated ? session.user.id : '';
    final r = await sl<ChatTools>().history(widget.chatId);
    if (!mounted) return;
    r.match((f) => setState(() => _error = f.message), (all) {
      // View-once media never shows up here.
      final visible = all.where((m) => !m.deletedForEveryone && !m.isHiddenFor(me) && !m.viewOnce).toList();
      setState(() {
        _media =
            visible
                .where((m) => (m.type == MessageType.image || m.type == MessageType.video) && m.mediaUrl != null)
                .toList();
        _docs = visible.where((m) => m.type == MessageType.file && m.mediaUrl != null).toList();
        _links = [
          for (final m in visible.where((m) => m.type == MessageType.text || m.text.isNotEmpty))
            for (final match in _urlRe.allMatches(m.text)) _LinkItem(match.group(0)!, m),
        ];
      });
    });
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Media, links and docs'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: 'Media${_loading ? '' : ' (${_media.length})'}'),
              Tab(text: 'Docs${_loading ? '' : ' (${_docs.length})'}'),
              Tab(text: 'Links${_loading ? '' : ' (${_links.length})'}'),
            ],
          ),
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load', message: _error!)
                : TabBarView(children: [_mediaGrid(), _docsList(), _linksList()]),
      ),
    );
  }

  Widget _mediaGrid() {
    if (_media.isEmpty) {
      return const EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No media',
        message: 'Photos and videos shared in this chat will appear here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _media.length,
      itemBuilder: (_, i) {
        final m = _media[i];
        final isVideo = m.type == MessageType.video;
        final tag = 'media-grid-${m.id}';
        return GestureDetector(
          onTap: () {
            if (isVideo) {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VideoPlayerPage(url: m.mediaUrl!)));
            } else {
              MediaViewerPage.open(context, url: m.mediaUrl!, heroTag: tag, caption: m.text.isEmpty ? null : m.text);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVideo)
                Container(
                  color: context.palette.surfaceHigh,
                  child: const Icon(Icons.movie_rounded, size: 36, color: AppColors.primary),
                )
              else
                Hero(
                  tag: tag,
                  child: CachedNetworkImage(
                    imageUrl: m.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: context.palette.surfaceHigh),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                  ),
                ),
              if (isVideo)
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _docsList() {
    if (_docs.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'No documents',
        message: 'Files shared in this chat will appear here.',
      );
    }
    return ListView.separated(
      itemCount: _docs.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: context.palette.stroke),
      itemBuilder: (_, i) {
        final m = _docs[i];
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary),
          ),
          title: Text(m.fileName ?? 'Document', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (m.fileSize != null) Formatters.fileSize(m.fileSize!),
              Formatters.chatListTime(m.createdAt),
            ].join(' • '),
          ),
          onTap: () => launchUrl(Uri.parse(m.mediaUrl!), mode: LaunchMode.externalApplication),
        );
      },
    );
  }

  Widget _linksList() {
    if (_links.isEmpty) {
      return const EmptyState(
        icon: Icons.link_off_rounded,
        title: 'No links',
        message: 'Links shared in this chat will appear here.',
      );
    }
    return ListView.separated(
      itemCount: _links.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: context.palette.stroke),
      itemBuilder: (_, i) {
        final l = _links[i];
        final host = Uri.tryParse(l.url)?.host ?? l.url;
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: context.palette.surfaceHigh, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.link_rounded, color: AppColors.primary),
          ),
          title: Text(host, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            l.url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.primary),
          ),
          trailing: Text(Formatters.chatListTime(l.message.createdAt), style: context.text.labelSmall),
          onTap: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
        );
      },
    );
  }
}
