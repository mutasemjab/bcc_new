import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Six animated boxes backed by one hidden TextField (supports paste + SMS autofill).
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, required this.onCompleted, this.hasError = false, this.length = 6});
  final ValueChanged<String> onCompleted;
  final bool hasError;
  final int length;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
      if (_controller.text.length == widget.length) widget.onCompleted(_controller.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    if (widget.hasError && !old.hasError) {
      HapticFeedback.heavyImpact();
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              final filled = i < text.length;
              final active = i == text.length && _focus.hasFocus;
              final borderColor =
                  widget.hasError
                      ? AppColors.danger
                      : active
                      ? AppColors.primary
                      : filled
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : context.palette.stroke;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 48,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.palette.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: active ? 2 : 1.2),
                  boxShadow:
                      active ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 14)] : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text(
                    filled ? text[i] : '',
                    key: ValueKey('$i-${filled ? text[i] : ''}'),
                    style: context.text.headlineSmall,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
