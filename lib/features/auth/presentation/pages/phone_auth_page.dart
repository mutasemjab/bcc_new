import 'package:bcc_chat/core/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../bloc/phone_auth/phone_auth_bloc.dart';
import '../widgets/auth_background.dart';
import '../widgets/country_code_picker.dart';
import '../widgets/otp_input.dart';

class PhoneAuthPage extends StatelessWidget {
  const PhoneAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PhoneAuthBloc>(),
      child: BlocConsumer<PhoneAuthBloc, PhoneAuthState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == PhoneAuthStatus.failure && state.message != null) {
            AppFeedback.error(context, state.message!);
          }
        },
        builder:
            (context, state) => PopScope(
              canPop: !state.isCodeStep,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) context.read<PhoneAuthBloc>().add(const PhoneNumberEditRequested());
              },
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(backgroundColor: Colors.transparent),
                body: AuthBackground(
                  child: SafeArea(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder:
                          (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                              child: child,
                            ),
                          ),
                      child:
                          state.isCodeStep
                              ? _CodeStep(key: const ValueKey('code'), state: state)
                              : _PhoneStep(key: const ValueKey('phone'), state: state),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _PhoneStep extends StatefulWidget {
  const _PhoneStep({super.key, required this.state});
  final PhoneAuthState state;
  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  Country _country = kCountries.first;
  final _number = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final digits = _number.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
    context.read<PhoneAuthBloc>().add(PhoneCodeRequested('${_country.dialCode}$digits'));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Text(tr('Your phone\nnumber'), style: context.text.displaySmall?.copyWith(fontSize: 36, height: 1.1)),
        const SizedBox(height: 10),
        Text(
          tr('We\'ll text you a 6-digit code to verify it\'s really you.'),
          style: context.text.bodyLarge?.copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: 32),
        GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final c = await showCountryPicker(context);
                      if (c != null) setState(() => _country = c);
                    },
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceHigh,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Text(_country.flag, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(_country.dialCode, style: context.text.titleMedium),
                          const Icon(Icons.expand_more_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _number,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                      style: context.text.titleMedium,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(hintText: tr('7X XXX XXXX')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              GradientButton(
                label: tr('Send code'),
                isLoading: widget.state.status == PhoneAuthStatus.loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(tr('Carrier SMS charges may apply.'), textAlign: TextAlign.center, style: context.text.labelSmall),
      ],
    );
  }
}

class _CodeStep extends StatefulWidget {
  const _CodeStep({super.key, required this.state});
  final PhoneAuthState state;
  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  static const _resendAfter = 60;
  Timer? _timer;
  int _secondsLeft = _resendAfter;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_CodeStep old) {
    super.didUpdateWidget(old);
    if (widget.state.codeSentAt != old.state.codeSentAt) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final sentAt = widget.state.codeSentAt ?? DateTime.now();
    void tick() {
      final left = _resendAfter - DateTime.now().difference(sentAt).inSeconds;
      setState(() => _secondsLeft = left.clamp(0, _resendAfter));
      if (left <= 0) _timer?.cancel();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bloc = context.read<PhoneAuthBloc>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Text(tr('Enter the\ncode'), style: context.text.displaySmall?.copyWith(fontSize: 36, height: 1.1)),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            text: tr('Sent by SMS to '),
            style: context.text.bodyLarge?.copyWith(color: context.palette.textSecondary),
            children: [
              TextSpan(
                text: state.phone ?? '',
                style: TextStyle(color: context.colors.onSurface, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
          onPressed: () => bloc.add(const PhoneNumberEditRequested()),
          child: Text(tr('Wrong number?')),
        ),
        const SizedBox(height: 20),
        GlassCard(
          child: Column(
            children: [
              OtpInput(
                hasError: state.status == PhoneAuthStatus.codeError,
                onCompleted: (code) => bloc.add(PhoneCodeSubmitted(code)),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child:
                    state.status == PhoneAuthStatus.codeError
                        ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(state.message ?? '', style: const TextStyle(color: AppColors.danger)),
                        )
                        : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 22),
              if (state.isBusy)
                const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
              else
                TextButton.icon(
                  onPressed: _secondsLeft == 0 ? () => bloc.add(const PhoneCodeResendRequested()) : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_secondsLeft == 0 ? tr('Resend code') : tr('Resend in {0}s', [_secondsLeft])),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
