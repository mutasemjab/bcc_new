import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/brand_logo.dart';

/// Help & support + company info.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  Future<void> _open(BuildContext context, Uri uri, String copyText) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: copyText));
      if (context.mounted) AppFeedback.info(context, tr('Copied: {0}', [copyText]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Help & support'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: BrandLogo(size: 72)),
          const SizedBox(height: 12),
          Center(child: Text(Env.companyName, style: context.text.titleLarge)),
          const SizedBox(height: 20),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.phone_rounded, color: AppColors.primary),
                title: Text(tr('Technical support (phone)')),
                subtitle: Text(Env.supportPhone),
                onTap: () => _open(context, Uri(scheme: 'tel', path: Env.supportPhone), Env.supportPhone),
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: AppColors.online),
                title: Text(tr('WhatsApp support')),
                subtitle: Text(Env.supportPhone),
                onTap:
                    () => _open(
                      context,
                      Uri.parse('https://wa.me/${Env.supportPhone.replaceAll(RegExp(r'[^0-9]'), '')}'),
                      Env.supportPhone,
                    ),
              ),
              ListTile(
                leading: const Icon(Icons.email_rounded, color: AppColors.primary),
                title: Text(tr('Technical support (email)')),
                subtitle: Text(Env.supportEmail),
                onTap:
                    () => _open(
                      context,
                      Uri(scheme: 'mailto', path: Env.supportEmail, query: 'subject=BCC Chat support'),
                      Env.supportEmail,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                title: Text(tr('Head office')),
                subtitle: Text(Env.companyAddress),
                onTap:
                    () => _open(
                      context,
                      Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(Env.companyAddress)}'),
                      Env.companyAddress,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(child: Text('${Env.appName} • v1.0.0', style: context.text.labelSmall)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(18)),
    child: Column(children: children),
  );
}
