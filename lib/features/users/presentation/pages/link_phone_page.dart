import 'package:flutter/material.dart';

import '../../../../app/di.dart';
import '../../../../core/services/contacts_service.dart';
import '../../../../core/services/phone_linker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../auth/presentation/widgets/country_code_picker.dart';
import '../../../auth/presentation/widgets/otp_input.dart';

/// "Add your phone number" for accounts created with email.
class LinkPhonePage extends StatefulWidget {
  const LinkPhonePage({super.key, this.current});
  final String? current;

  @override
  State<LinkPhonePage> createState() => _LinkPhonePageState();
}

class _LinkPhonePageState extends State<LinkPhonePage> {
  final _number = TextEditingController();
  Country _country = kCountries.first;
  String? _verificationId;
  String? _phone;
  bool _busy = false;
  bool _codeError = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = PhoneNumbers.normalize(
      '${_country.dialCode}${_number.text.replaceFirst(RegExp(r'^0+'), '')}',
      _country.dialCode,
    );
    if (phone == null) {
      AppFeedback.error(context, 'Enter a valid phone number.');
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await sl<PhoneLinker>().sendCode(phone);
      if (!mounted) return;
      if (id == null) return _done();
      setState(() {
        _verificationId = id;
        _phone = phone;
      });
    } catch (e) {
      if (mounted) AppFeedback.error(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String code) async {
    final id = _verificationId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _codeError = false;
    });
    try {
      await sl<PhoneLinker>().confirmCode(id, code);
      if (mounted) _done();
    } catch (e) {
      if (mounted) {
        setState(() => _codeError = true);
        AppFeedback.error(context, '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done() {
    AppFeedback.info(context, 'Phone number added — friends can now find you');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.palette.textSecondary, height: 1.4);
    return Scaffold(
      appBar: AppBar(title: Text(widget.current == null ? 'Add phone number' : 'Change phone number')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_verificationId == null) ...[
            Text(
              'Add your number so friends who saved it in their contacts can find you on BCC Chat. '
              "We'll send a code by SMS to confirm it's yours.",
              style: secondary,
            ),
            if (widget.current != null) ...[
              const SizedBox(height: 8),
              Text('Current number: ${widget.current}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final c = await showCountryPicker(context);
                    if (c != null) setState(() => _country = c);
                  },
                  child: Text('${_country.flag} ${_country.dialCode}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _number,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '79 123 4567'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GradientButton(label: 'Send code', icon: Icons.sms_rounded, isLoading: _busy, onPressed: _send),
          ] else ...[
            Text('Enter the 6-digit code sent to', style: secondary),
            const SizedBox(height: 4),
            Text(_phone ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 24),
            OtpInput(onCompleted: _confirm, hasError: _codeError),
            const SizedBox(height: 16),
            if (_busy) const Center(child: CircularProgressIndicator()),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _verificationId = null),
              child: const Text('Change number', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
