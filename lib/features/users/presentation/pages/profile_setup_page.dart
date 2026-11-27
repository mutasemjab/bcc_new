import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../core/services/media_picker_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../auth/presentation/bloc/session/session_bloc.dart';
import '../bloc/profile/profile_bloc.dart';

/// First-run profile setup, also reused for "Edit profile".
class ProfileSetupPage extends StatelessWidget {
  const ProfileSetupPage({super.key, this.isEditing = false});
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileBloc>()..add(const ProfileLoaded()),
      child: _ProfileView(isEditing: isEditing),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView({required this.isEditing});
  final bool isEditing;
  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _name = TextEditingController();
  final _about = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = sl<MediaPickerService>();
    final source = await showModalBottomSheet<bool>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text(tr('Take photo')),
                  onTap: () => Navigator.pop(ctx, true),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text(tr('Choose from gallery')),
                  onTap: () => Navigator.pop(ctx, false),
                ),
              ],
            ),
          ),
    );
    if (source == null || !mounted) return;
    final file = await picker.pickImage(camera: source);
    if (file != null && mounted) context.read<ProfileBloc>().add(ProfileAvatarPicked(file));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state.user != null && !_prefilled) {
          _prefilled = true;
          _name.text = state.user!.name;
          _about.text = state.user!.about;
        }
        if (state.status == ProfileStatus.failure) AppFeedback.error(context, state.message ?? tr('Error'));
        if (state.status == ProfileStatus.saved && widget.isEditing) {
          AppFeedback.success(context, tr('Profile updated'));
          context.pop();
        }
        // First-run: SessionBloc sees the new profile and the router moves on.
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.isEditing ? tr('Edit profile') : ''),
            actions: [
              if (!widget.isEditing)
                TextButton(
                  onPressed: () => context.read<SessionBloc>().add(const SessionSignOutRequested()),
                  child: Text(tr('Sign out')),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                if (!widget.isEditing) ...[
                  Text(
                    tr('Set up your\nprofile'),
                    style: context.text.displaySmall?.copyWith(fontSize: 34, height: 1.1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Add a name and photo so friends recognise you.'),
                    style: context.text.bodyLarge?.copyWith(color: context.palette.textSecondary),
                  ),
                ],
                const SizedBox(height: 32),
                Center(child: _AvatarPicker(file: state.avatar, url: state.user?.photoUrl, onTap: _pickAvatar)),
                const SizedBox(height: 32),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 40,
                  decoration: InputDecoration(
                    hintText: tr('Your name'),
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _about,
                  maxLength: 140,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: tr('About (optional)'),
                    prefixIcon: Icon(Icons.info_outline_rounded),
                  ),
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: widget.isEditing ? tr('Save changes') : tr('Get started'),
                  isLoading: state.status == ProfileStatus.saving,
                  onPressed:
                      () => context.read<ProfileBloc>().add(ProfileSubmitted(name: _name.text, about: _about.text)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({this.file, this.url, required this.onTap});
  final File? file;
  final String? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (file != null) {
      image = FileImage(file!);
    } else if (url != null && url!.isNotEmpty) {
      image = CachedNetworkImageProvider(url!);
    }
    return Pressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.palette.surfaceHigh,
                image: image == null ? null : DecorationImage(image: image, fit: BoxFit.cover),
              ),
              child: image == null ? Icon(Icons.person_rounded, size: 64, color: context.palette.textSecondary) : null,
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: context.theme.scaffoldBackgroundColor, width: 3),
              ),
              child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
