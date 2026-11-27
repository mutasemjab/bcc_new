import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/di.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../domain/entities/group_invite.dart';
import '../domain/usecases/chat_extras.dart';

/// Picks up group invitations that were sent to my email before I had an
/// account. Requires a verified email (so nobody can claim someone else's).
class EmailInviteClaimer extends ChangeNotifier with WidgetsBindingObserver {
  EmailInviteClaimer(this._auth, this._membership);
  final FirebaseAuth _auth;
  final GroupMembership _membership;

  bool _needsVerification = false;
  bool _started = false;

  /// Signed in with an email that isn't verified yet.
  bool get needsVerification => _needsVerification;
  String? get email => _auth.currentUser?.email;

  void start() {
    if (!_started) WidgetsBinding.instance.addObserver(this);
    _started = true;
    check();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _needsVerification = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the email app after tapping the verification link.
    if (state == AppLifecycleState.resumed && _needsVerification) check();
  }

  /// Re-reads the account; claims invitations once the email is verified.
  Future<bool> check() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      _setNeeds(false);
      return false;
    }
    try {
      await user.reload();
    } catch (_) {}
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) {
      _setNeeds(true);
      return false;
    }
    _setNeeds(false);
    await fresh.getIdToken(true); // the rules read "email_verified" from the token
    await _membership.claimEmailInvites(fresh.uid, email.toLowerCase());
    return true;
  }

  Future<String?> sendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } catch (e) {
      return tr('Could not send the email. Try again in a minute.');
    }
  }

  void _setNeeds(bool v) {
    if (_needsVerification == v) return;
    _needsVerification = v;
    notifyListeners();
  }
}

/// Banner on the chats list until the email is verified.
class VerifyEmailBanner extends StatelessWidget {
  const VerifyEmailBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final claimer = sl<EmailInviteClaimer>();
    return ListenableBuilder(
      listenable: claimer,
      builder: (context, _) {
        if (!claimer.needsVerification) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mark_email_unread_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(child: Text(tr('Verify your email'), style: TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr('Confirm {0} to receive group invitations sent to it.', [claimer.email ?? 'your email']),
                style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      final err = await claimer.sendVerification();
                      if (context.mounted) {
                        AppFeedback.info(context, err ?? tr('Verification link sent — check your inbox (and spam).'));
                      }
                    },
                    child: Text(tr('Send link')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final ok = await claimer.check();
                      if (context.mounted && !ok) {
                        AppFeedback.info(context, tr('Not verified yet — tap the link in the email first.'));
                      }
                    },
                    child: Text(tr('I\'ve verified')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Paste / type emails (any separator). Returns the valid ones.
Future<List<String>?> showEmailInviteSheet(BuildContext context) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _EmailInviteSheet(),
  );
}

class _EmailInviteSheet extends StatefulWidget {
  const _EmailInviteSheet();
  @override
  State<_EmailInviteSheet> createState() => _EmailInviteSheetState();
}

class _EmailInviteSheetState extends State<_EmailInviteSheet> {
  final _text = TextEditingController();
  List<String> _emails = const [];

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() => _emails = GroupMembership.parseEmails(_text.text)));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Invite by email'), style: context.text.titleLarge),
          const SizedBox(height: 6),
          Text(
            tr(
              'Add the emails of people you want in the group — even if they don\'t have the app yet. When they sign up with the same email, the invitation will be waiting for them.',
            ),
            style: TextStyle(color: context.palette.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: tr('name@example.com, other@example.com…\n(paste a whole list)')),
          ),
          const SizedBox(height: 8),
          if (_emails.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final e in _emails) Chip(label: Text(e), visualDensity: VisualDensity.compact)],
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _emails.isEmpty ? null : () => Navigator.pop(context, _emails),
              icon: const Icon(Icons.group_add_rounded),
              label: Text(_emails.isEmpty ? tr('Add emails') : tr('Invite {0}', [_emails.length])),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sends the invitation from the user's own email app (works without any
/// server email setup). Everyone goes in BCC so addresses stay private.
Future<void> sendInvitationEmails(
  BuildContext context, {
  required List<String> emails,
  required String groupName,
  required String inviterName,
  String? chatId,
  String? inviteCode,
}) async {
  final link = chatId != null && inviteCode != null ? GroupLinks.build(chatId, inviteCode) : null;
  final subject = tr('{0} invited you to "{1}" on {2}', [inviterName, groupName, Env.appName]);
  final body = [
    'Hi!',
    '',
    tr('{0} invited you to join the group "{1}" on {2}.', [inviterName, groupName, Env.appName]),
    '',
    tr('1) Download the app: {0}', [Env.downloadUrl]),
    tr('2) Sign up with THIS email address and confirm it.'),
    tr('3) The group invitation will be waiting for you in the app.'),
    if (link != null) ...[
      '',
      tr('Or open this link after installing: {0}', [link]),
    ],
  ].join('\n');
  final uri = Uri(scheme: 'mailto', queryParameters: {'bcc': emails.join(','), 'subject': subject, 'body': body});
  // mailto needs %20 rather than '+' for spaces.
  final fixed = Uri.parse(uri.toString().replaceAll('+', '%20'));
  if (!await launchUrl(fixed)) {
    await SharePlus.instance.share(ShareParams(text: '$subject\n\n$body', subject: subject));
  }
}
