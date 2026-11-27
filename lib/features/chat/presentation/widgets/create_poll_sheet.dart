import 'package:bcc_chat/core/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../domain/entities/message_entity.dart';

/// Full-height sheet to compose a poll: question, 2–12 options, single or
/// multiple answers. Returns null when dismissed.
Future<PollData?> showCreatePollSheet(BuildContext context) => showModalBottomSheet<PollData>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const _CreatePollSheet(),
);

class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();
  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  static const _maxOptions = 12;
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _multiple = false;

  @override
  void initState() {
    super.initState();
    _question.addListener(() => setState(() {}));
    for (final c in _options) {
      c.addListener(_onOptionChanged);
    }
  }

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  /// Like WhatsApp: typing into the last option adds a new empty one.
  void _onOptionChanged() {
    if (_options.last.text.trim().isNotEmpty && _options.length < _maxOptions) {
      final c = TextEditingController()..addListener(_onOptionChanged);
      _options.add(c);
    }
    setState(() {});
  }

  List<String> get _filled => _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
  bool get _valid => _question.text.trim().isNotEmpty && _filled.length >= 2;

  void _submit() {
    if (!_valid) return;
    final opts = _filled;
    Navigator.pop(
      context,
      PollData(
        question: _question.text.trim(),
        allowMultiple: _multiple,
        options: [for (final (i, t) in opts.indexed) PollOption(id: 'o$i', text: t)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                Expanded(child: Text(tr('Create poll'), style: context.text.titleLarge)),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              children: [
                Text('QUESTION', style: _label(context)),
                const SizedBox(height: 8),
                TextField(
                  controller: _question,
                  autofocus: true,
                  maxLength: 255,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: tr('Ask a question'), counterText: ''),
                ),
                const SizedBox(height: 18),
                Text('OPTIONS', style: _label(context)),
                const SizedBox(height: 8),
                for (final (i, c) in _options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: c,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: tr('Option {0}', [i + 1]),
                        counterText: '',
                        prefixIcon: const Icon(Icons.drag_indicator_rounded),
                        suffixIcon:
                            _options.length > 2 && c.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() => _options.removeAt(i).dispose()),
                                )
                                : null,
                      ),
                    ),
                  ),
                if (_options.length >= _maxOptions)
                  Text(tr('You can add up to {0} options.', [_maxOptions]), style: _label(context)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _multiple,
                  onChanged: (v) => setState(() => _multiple = v),
                  activeThumbColor: AppColors.primary,
                  title: Text(tr('Allow multiple answers')),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: GradientButton(
                label: tr('Send poll'),
                icon: Icons.send_rounded,
                onPressed: _valid ? _submit : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _label(BuildContext context) =>
      context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1);
}
