import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../bloc/email_auth/email_auth_bloc.dart';
import '../widgets/auth_background.dart';

class EmailAuthPage extends StatelessWidget {
  const EmailAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<EmailAuthBloc>(), child: const _EmailAuthView());
  }
}

class _EmailAuthView extends StatefulWidget {
  const _EmailAuthView();
  @override
  State<_EmailAuthView> createState() => _EmailAuthViewState();
}

class _EmailAuthViewState extends State<_EmailAuthView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit(EmailAuthState state) {
    FocusScope.of(context).unfocus();
    if (state.isSignUp && _password.text != _confirm.text) {
      AppFeedback.error(context, 'Passwords do not match.');
      return;
    }
    context.read<EmailAuthBloc>().add(EmailAuthSubmitted(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmailAuthBloc, EmailAuthState>(
      listener: (context, state) {
        if (state.status == EmailAuthStatus.failure && state.message != null) {
          AppFeedback.error(context, state.message!);
        } else if (state.status == EmailAuthStatus.resetSent) {
          AppFeedback.success(context, state.message!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(backgroundColor: Colors.transparent),
          body: AuthBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey(state.isSignUp),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isSignUp ? 'Create your\naccount' : 'Welcome\nback',
                          style: context.text.displaySmall?.copyWith(fontSize: 36, height: 1.1),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          state.isSignUp
                              ? 'Join BCC Chat with your email address.'
                              : 'Sign in to pick up where you left off.',
                          style: context.text.bodyLarge?.copyWith(color: context.palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassCard(
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Email address',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: [state.isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                            textInputAction: state.isSignUp ? TextInputAction.next : TextInputAction.done,
                            onSubmitted: state.isSignUp ? null : (_) => _submit(state),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child:
                                state.isSignUp
                                    ? Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: TextField(
                                        controller: _confirm,
                                        obscureText: _obscure,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _submit(state),
                                        decoration: const InputDecoration(
                                          hintText: 'Confirm password',
                                          prefixIcon: Icon(Icons.lock_reset_rounded),
                                        ),
                                      ),
                                    )
                                    : const SizedBox(width: double.infinity),
                          ),
                          if (!state.isSignUp)
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed:
                                    state.isLoading
                                        ? null
                                        : () => context.read<EmailAuthBloc>().add(PasswordResetRequested(_email.text)),
                                child: const Text('Forgot password?'),
                              ),
                            )
                          else
                            const SizedBox(height: 20),
                          GradientButton(
                            label: state.isSignUp ? 'Create account' : 'Sign in',
                            isLoading: state.isLoading,
                            onPressed: () => _submit(state),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.isSignUp ? 'Already have an account?' : 'New to BCC Chat?',
                        style: TextStyle(color: context.palette.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => context.read<EmailAuthBloc>().add(const EmailAuthModeToggled()),
                        child: Text(state.isSignUp ? 'Sign in' : 'Create account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
