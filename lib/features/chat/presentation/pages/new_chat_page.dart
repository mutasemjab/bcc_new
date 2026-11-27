import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../users/domain/entities/user_entity.dart';
import '../../../users/domain/usecases/user_usecases.dart';
import '../../../users/presentation/contact_sync.dart';
import '../../../users/presentation/pages/invite_contacts_page.dart';
import '../../../users/presentation/pages/link_phone_page.dart';
import '../../../users/presentation/bloc/user_search/user_search_cubit.dart';
import '../../../users/presentation/widgets/user_tile.dart';
import '../../domain/entities/group_invite.dart';
import '../bloc/chat_list/chat_list_bloc.dart';

/// Pick someone to chat with: phone contacts on the app, recent people,
/// and global search.
class NewChatPage extends StatelessWidget {
  const NewChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<ChatListBloc>().state.uid;
    final session = context.read<SessionBloc>().state;
    final myPhone = session is SessionAuthenticated ? session.user.phone : null;
    // Contacts come from the on-device cache (instant); ContactSync keeps it
    // fresh in the background. First time here → ask for contacts permission.
    WidgetsBinding.instance.addPostFrameCallback((_) => sl<ContactSync>().askOnceIfNeeded());
    return BlocProvider(
      create: (_) => UserSearchCubit(sl<SearchUsers>(), uid),
      child: ListenableBuilder(
        listenable: sl<ContactSync>(),
        builder: (context, _) => _NewChatView(myUid: uid, myPhone: myPhone),
      ),
    );
  }
}

class _NewChatView extends StatelessWidget {
  const _NewChatView({required this.myUid, required this.myPhone});
  final String myUid;
  final String? myPhone;

  void _open(BuildContext context, UserEntity user) {
    context.pushReplacement(AppRoutes.conversation(IdUtils.directChatId(myUid, user.id)));
  }

  Future<void> _joinViaLink(BuildContext context) async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && GroupLinks.parse(clip!.text!) != null) controller.text = clip.text!.trim();
    if (!context.mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(tr('Join group via link')),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: tr('Paste the invite link')),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
              TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(tr('Open'))),
            ],
          ),
    );
    controller.dispose();
    if (text == null || !context.mounted) return;
    final link = GroupLinks.parse(text);
    if (link == null) {
      AppFeedback.error(context, tr('That doesn\'t look like a BCC Chat group link.'));
      return;
    }
    context.push(AppRoutes.joinGroup(link.$1, link.$2));
  }

  ContactSync get _sync => sl<ContactSync>();

  @override
  Widget build(BuildContext context) {
    final recent = context.select((ChatListBloc b) => b.state.contacts);
    final sync = _sync;
    final contacts = sync.matches;
    final inPhoneBook = {for (final m in contacts) m.uid};
    final others = recent.where((u) => !inPhoneBook.contains(u.id)).toList();
    final firstSync = sync.syncing && contacts.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('New chat')),
        actions: [
          IconButton(
            tooltip: tr('Refresh contacts'),
            onPressed: sync.syncing || !sync.hasAccess ? null : () => sync.sync(full: true),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: BlocBuilder<UserSearchCubit, UserSearchState>(
        builder: (context, search) {
          final searching = search.query.trim().length >= 2;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: TextField(
                    onChanged: context.read<UserSearchCubit>().queryChanged,
                    decoration: InputDecoration(
                      hintText: tr('Name, email or phone (+962…)'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          search.isLoading
                              ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                              : null,
                    ),
                  ),
                ),
              ),
              if (!searching) ...[
                SliverToBoxAdapter(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                      child: const Icon(Icons.group_add_rounded, color: Colors.white),
                    ),
                    title: Text(tr('New group'), style: context.text.titleMedium),
                    onTap: () => context.pushReplacement(AppRoutes.newGroup),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: context.palette.surfaceHigh),
                      child: const Icon(Icons.link_rounded, color: AppColors.primary),
                    ),
                    title: Text(tr('Join group via link'), style: context.text.titleMedium),
                    onTap: () => _joinViaLink(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: context.palette.surfaceHigh),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                    ),
                    title: Text(tr('Invite friends'), style: context.text.titleMedium),
                    subtitle: Text(tr('Contacts who don\'t have BCC Chat yet')),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => InviteContactsPage(myPhone: myPhone))),
                  ),
                ),
                // Email accounts without a number can't be found by friends' phone books.
                if (myPhone == null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.phone_android_rounded, color: AppColors.primary),
                        title: Text(tr('Add your phone number')),
                        subtitle: Text(tr('So friends who saved your number can find you')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap:
                            () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute<void>(builder: (_) => const LinkPhonePage())),
                      ),
                    ),
                  ),

                // ── Phone contacts that use the app (cached on the device) ──
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    tr('Contacts on BCC Chat'),
                    trailing:
                        sync.syncing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : contacts.isEmpty
                            ? null
                            : Text('${contacts.length}', style: context.text.labelSmall),
                  ),
                ),
                if (!sync.hasAccess)
                  SliverToBoxAdapter(child: _ContactsPermissionCard(onAllow: sync.requestAccessAndSync))
                else if (contacts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text(
                        firstSync
                            ? tr('Finding your contacts on BCC Chat…')
                            : sync.error ?? tr('None of your contacts are on BCC Chat yet.'),
                        style: TextStyle(color: context.palette.textSecondary),
                      ),
                    ),
                  ),
                SliverList.builder(
                  itemCount: contacts.length,
                  itemBuilder: (_, i) {
                    final m = contacts[i];
                    final user = m.toUser();
                    return UserTile(
                      user: user,
                      title: m.contactName,
                      subtitle: m.about.isNotEmpty ? m.about : m.phone,
                      onTap: () => _open(context, user),
                    );
                  },
                ),

                // ── Other people you've chatted with ──
                if (others.isNotEmpty) SliverToBoxAdapter(child: _SectionHeader(tr('People you know'))),
                SliverList.builder(
                  itemCount: others.length,
                  itemBuilder: (_, i) => UserTile(user: others[i], onTap: () => _open(context, others[i])),
                ),
                if (others.isEmpty && contacts.isEmpty && !sync.syncing && sync.hasAccess)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.person_search_rounded,
                      title: tr('Find your people'),
                      message: tr('Search by name, email or phone number to start chatting.'),
                    ),
                  ),
              ] else ...[
                ..._localMatches(context, contacts, search.query),
                ..._remoteResults(context, search, inPhoneBook),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Phone-book contacts whose saved name or number matches — no network.
  List<Widget> _localMatches(BuildContext context, List<SyncedContact> contacts, String query) {
    final q = query.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    final hits =
        contacts
            .where(
              (c) =>
                  c.contactName.toLowerCase().contains(q) ||
                  c.profileName.toLowerCase().contains(q) ||
                  (digits.length >= 3 && c.phone.contains(digits)),
            )
            .toList();
    if (hits.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: _SectionHeader(tr('Contacts'))),
      SliverList.builder(
        itemCount: hits.length,
        itemBuilder: (_, i) {
          final user = hits[i].toUser();
          return UserTile(user: user, title: hits[i].contactName, onTap: () => _open(context, user));
        },
      ),
    ];
  }

  List<Widget> _remoteResults(BuildContext context, UserSearchState search, Set<String> alreadyShown) {
    final results = search.results.where((u) => !alreadyShown.contains(u.id)).toList();
    return [
      if (search.error != null)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(icon: Icons.wifi_off_rounded, title: tr('Search failed'), message: search.error!),
        )
      else if (!search.isLoading && results.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: tr('No one else found'),
            message: tr('Check the spelling, or search by exact email / phone with country code.'),
          ),
        )
      else ...[
        SliverToBoxAdapter(child: _SectionHeader(tr('On BCC Chat'))),
        SliverList.builder(
          itemCount: results.length,
          itemBuilder: (_, i) => UserTile(user: results[i], onTap: () => _open(context, results[i])),
        ),
      ],
    ];
  }
}

class _ContactsPermissionCard extends StatelessWidget {
  const _ContactsPermissionCard({required this.onAllow});
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.palette.surfaceHigh, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contacts_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(tr('See who you know'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Allow access to your contacts to find friends who already use BCC Chat. Your contacts are only used for matching on this device.',
            ),
            style: TextStyle(color: context.palette.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(onPressed: onAllow, child: Text(tr('Allow access'))),
              const SizedBox(width: 8),
              TextButton(onPressed: openAppSettings, child: Text(tr('Open settings'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}
