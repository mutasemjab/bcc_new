import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/routes.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../../../users/domain/entities/user_entity.dart';
import '../../../users/domain/usecases/user_usecases.dart';
import '../../../users/presentation/bloc/user_search/user_search_cubit.dart';
import '../../../users/presentation/contact_sync.dart';
import '../../../users/presentation/pages/invite_contacts_page.dart';
import '../../../users/presentation/widgets/user_tile.dart';
import '../../domain/usecases/group_usecases.dart';
import '../bloc/chat_list/chat_list_bloc.dart';
import '../bloc/group/create_group_cubit.dart';

class CreateGroupPage extends StatelessWidget {
  const CreateGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionBloc>().state;
    if (session is! SessionAuthenticated) return const Scaffold();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CreateGroupCubit(sl<CreateGroup>(), me: session.user)),
        BlocProvider(create: (_) => UserSearchCubit(sl<SearchUsers>(), session.user.id)),
      ],
      child: BlocConsumer<CreateGroupCubit, CreateGroupState>(
        listener: (context, state) {
          if (state.error != null) AppFeedback.error(context, state.error!);
          if (state.status == CreateGroupStatus.created && state.chatId != null) {
            context.pushReplacement(AppRoutes.conversation(state.chatId!));
          }
        },
        builder:
            (context, state) => PopScope(
              canPop: state.step == CreateGroupStep.members,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) context.read<CreateGroupCubit>().back();
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child:
                    state.step == CreateGroupStep.members
                        ? const _MembersStep(key: ValueKey('members'))
                        : const _DetailsStep(key: ValueKey('details')),
              ),
            ),
      ),
    );
  }
}

/// Reusable member picker (also used by "Add members" in group info).
/// Picks group members from: phone contacts on BCC Chat, people you already
/// chat with, and search (name / email / any phone format). People without
/// the app can't be added — they get an invite instead (same as WhatsApp).
class MemberPicker extends StatelessWidget {
  const MemberPicker({super.key, required this.isSelected, required this.onToggle, this.excludeIds = const {}});
  final bool Function(String uid) isSelected;
  final ValueChanged<UserEntity> onToggle;
  final Set<String> excludeIds;

  @override
  Widget build(BuildContext context) {
    final recent = context.select((ChatListBloc b) => b.state.contacts);
    return ListenableBuilder(
      listenable: sl<ContactSync>(),
      builder: (context, _) {
        final synced = sl<ContactSync>().matches;
        // Phone-book contacts first (with their saved names), then others.
        final names = <String, String>{for (final c in synced) c.uid: c.contactName};
        final people = <String, UserEntity>{for (final c in synced) c.uid: c.toUser(), for (final u in recent) u.id: u}
          ..removeWhere((id, _) => excludeIds.contains(id));

        return BlocBuilder<UserSearchCubit, UserSearchState>(
          builder: (context, search) {
            final q = search.query.trim().toLowerCase();
            final searching = q.length >= 2;
            final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
            final local =
                people.values
                    .where(
                      (u) =>
                          !searching ||
                          (names[u.id] ?? u.name).toLowerCase().contains(q) ||
                          u.name.toLowerCase().contains(q) ||
                          (digits.length >= 3 && (u.phone ?? '').contains(digits)),
                    )
                    .toList()
                  ..sort(
                    (a, b) => (names[a.id] ?? a.name).toLowerCase().compareTo((names[b.id] ?? b.name).toLowerCase()),
                  );
            final remote =
                searching
                    ? search.results.where((u) => !excludeIds.contains(u.id) && !people.containsKey(u.id)).toList()
                    : const <UserEntity>[];
            final list = [...local, ...remote];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: TextField(
                    onChanged: context.read<UserSearchCubit>().queryChanged,
                    decoration: InputDecoration(
                      hintText: 'Search name, email or phone',
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
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                  title: const Text('Invite friends to BCC Chat'),
                  subtitle: const Text("For contacts who don't have the app yet"),
                  onTap: () {
                    final session = context.read<SessionBloc>().state;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => InviteContactsPage(
                              myPhone: session is SessionAuthenticated ? session.user.phone : null,
                            ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child:
                      list.isEmpty
                          ? EmptyState(
                            icon: Icons.group_rounded,
                            title: searching ? 'No one found' : 'No contacts yet',
                            message:
                                searching
                                    ? 'Try another name, email or phone number.'
                                    : 'Your contacts on BCC Chat appear here. Search to find more people.',
                          )
                          : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final u = list[i];
                              final selected = isSelected(u.id);
                              return UserTile(
                                user: u,
                                title: names[u.id],
                                subtitle: u.about.isNotEmpty ? u.about : (u.phone ?? u.email ?? ''),
                                onTap: () => onToggle(u),
                                trailing: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: selected ? AppColors.brandGradient : null,
                                    border: selected ? null : Border.all(color: context.palette.stroke, width: 2),
                                  ),
                                  child:
                                      selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
                                ),
                              );
                            },
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MembersStep extends StatelessWidget {
  const _MembersStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateGroupCubit>();
    final state = context.watch<CreateGroupCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New group'),
            Text(
              state.selected.isEmpty ? 'Invite members' : '${state.selected.length} will be invited',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: state.selected.isEmpty ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: cubit.next,
          child: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child:
                state.selected.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        itemCount: state.selected.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          final u = state.selected[i];
                          return Pressable(
                            onTap: () => cubit.toggle(u),
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AppAvatar(name: u.name, imageUrl: u.photoUrl, size: 54),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: context.palette.textSecondary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: context.theme.scaffoldBackgroundColor, width: 2),
                                        ),
                                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    u.name.split(' ').first,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
          ),
          Expanded(child: MemberPicker(isSelected: state.isSelected, onToggle: cubit.toggle)),
        ],
      ),
    );
  }
}

class _DetailsStep extends StatefulWidget {
  const _DetailsStep({super.key});
  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateGroupCubit>();
    final state = context.watch<CreateGroupCubit>().state;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: cubit.back), title: const Text('Group details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Pressable(
              onTap: () async {
                final f = await sl<MediaPickerService>().pickImage();
                if (f != null) cubit.setPhoto(f);
              },
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: state.photo == null ? AppColors.brandGradient : null,
                  image:
                      state.photo == null ? null : DecorationImage(image: FileImage(state.photo!), fit: BoxFit.cover),
                ),
                child:
                    state.photo == null ? const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 36) : null,
              ),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Group name', prefixIcon: Icon(Icons.groups_rounded)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLength: 300,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Description (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Text('${state.selected.length} invitations will be sent', style: context.text.labelSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in state.selected)
                Chip(
                  avatar: AppAvatar(name: u.name, imageUrl: u.photoUrl, size: 24),
                  label: Text(u.name.split(' ').first),
                  side: BorderSide.none,
                  backgroundColor: context.palette.surfaceHigh,
                ),
            ],
          ),
          const SizedBox(height: 32),
          GradientButton(
            label: 'Create group',
            icon: Icons.check_rounded,
            isLoading: state.status == CreateGroupStatus.creating,
            onPressed: () => cubit.create(name: _name.text, description: _description.text.trim()),
          ),
        ],
      ),
    );
  }
}
