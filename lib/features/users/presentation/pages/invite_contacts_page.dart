import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di.dart';
import '../../../../core/config/env.dart';
import '../../../../core/services/contacts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../contact_sync.dart';

/// Phone contacts who don't have the app yet — invite them by SMS / any app
/// (WhatsApp works the same way: non-users can't be added, only invited).
class InviteContactsPage extends StatefulWidget {
  const InviteContactsPage({super.key, this.myPhone});
  final String? myPhone;

  static String inviteText() =>
      tr('Let\'s chat on {0}! It\'s fast and private. Download it here: {1}', [Env.appName, Env.downloadUrl]);

  @override
  State<InviteContactsPage> createState() => _InviteContactsPageState();
}

class _InviteContactsPageState extends State<InviteContactsPage> {
  List<PhoneContact>? _contacts;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = sl<ContactsService>();
    if (await service.requestAccess() != ContactsAccess.granted) {
      if (mounted) setState(() => _error = tr('Allow access to your contacts to invite friends.'));
      return;
    }
    final book = await service.readContacts(defaultCountryCode: PhoneNumbers.countryCodeOf(widget.myPhone));
    final onApp = {for (final m in sl<ContactSync>().matches) m.phone};
    final list =
        book.where((c) => !c.phones.any(onApp.contains)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) setState(() => _contacts = list);
  }

  Future<void> _invite(PhoneContact c) async {
    final text = InviteContactsPage.inviteText();
    final phone = c.phones.first;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.sms_rounded, color: AppColors.primary),
                  title: Text(tr('Send SMS to {0}', [c.name])),
                  subtitle: Text(phone),
                  onTap: () => Navigator.pop(ctx, 'sms'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: AppColors.primary),
                  title: Text(tr('Share with another app')),
                  onTap: () => Navigator.pop(ctx, 'share'),
                ),
              ],
            ),
          ),
    );
    if (choice == 'sms') {
      final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': text});
      if (!await launchUrl(uri)) await SharePlus.instance.share(ShareParams(text: text));
    } else if (choice == 'share') {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list =
        (_contacts ?? const <PhoneContact>[])
            .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.phones.any((p) => p.contains(q)))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Invite to BCC Chat')),
        actions: [
          IconButton(
            tooltip: tr('Share invite link'),
            icon: const Icon(Icons.share_rounded),
            onPressed: () => SharePlus.instance.share(ShareParams(text: InviteContactsPage.inviteText())),
          ),
        ],
      ),
      body:
          _error != null
              ? EmptyState(icon: Icons.contacts_rounded, title: tr('Contacts needed'), message: _error!)
              : _contacts == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: tr('Search contacts'),
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return ListTile(
                          leading: AppAvatar(name: c.name, size: 42),
                          title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.phones.first),
                          trailing: TextButton(onPressed: () => _invite(c), child: Text(tr('Invite'))),
                          onTap: () => _invite(c),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
