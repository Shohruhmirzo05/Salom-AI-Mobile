// Card input for Click tokenization (auto-renew flow). Sends card_number +
// expire_date to backend, which forwards them to Click and returns a request_id
// + phone_hint to display while waiting for SMS.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/features/settings/sms_verify_sheet.dart';

class CardInputSheet extends ConsumerStatefulWidget {
  final String planCode;
  const CardInputSheet({super.key, required this.planCode});

  @override
  ConsumerState<CardInputSheet> createState() => _CardInputSheetState();
}

class _CardInputSheetState extends ConsumerState<CardInputSheet> {
  final _cardCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cardFocus = FocusNode();
  final _expFocus = FocusNode();
  bool _loading = false;
  String? _error;

  static const _clickBlue = Color(0xFF0065FF);

  String get _cardDigits => _cardCtrl.text.replaceAll(RegExp(r'\D'), '');
  String get _expDigits => _expCtrl.text.replaceAll(RegExp(r'\D'), '');
  bool get _valid => _cardDigits.length == 16 && _expDigits.length == 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cardFocus.requestFocus());
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _expCtrl.dispose();
    _cardFocus.dispose();
    _expFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(subscriptionManagerProvider.notifier).tokenizeCard(
          cardNumber: _cardDigits,
          expireDate: _expDigits,
        );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = ref.tr('card_tokenize_error');
      });
      return;
    }
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SmsVerifySheet(
          planCode: widget.planCode,
          requestId: result['request_id'] as String,
          phoneHint: (result['phone_hint'] as String?) ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = ref;
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          r.tr('card_input_title'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                r.tr('card_input_subtitle'),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              _Field(
                label: r.tr('card_number_label'),
                controller: _cardCtrl,
                focus: _cardFocus,
                hint: '8600 1234 5678 9012',
                icon: Icons.credit_card_rounded,
                maxLength: 19,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardNumberFormatter(),
                ],
                onChanged: (v) {
                  if (v.replaceAll(' ', '').length == 16) _expFocus.requestFocus();
                  setState(() {});
                },
              ),
              const SizedBox(height: 14),
              _Field(
                label: r.tr('card_expiry_label'),
                controller: _expCtrl,
                focus: _expFocus,
                hint: 'MM/YY',
                icon: Icons.calendar_today_rounded,
                maxLength: 5,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ExpiryFormatter(),
                ],
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(text: _error!),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (!_valid || _loading) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _clickBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _clickBlue.withOpacity(0.3),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(r.tr('continue'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _securityBadge(Icons.lock_outline_rounded, 'SSL'),
                  _securityBadge(Icons.verified_user_outlined, 'PCI DSS'),
                  _securityBadge(Icons.visibility_off_outlined, r.tr('card_secure_private')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _securityBadge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.white24),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final IconData icon;
  final int maxLength;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onChanged;

  const _Field({
    required this.label,
    required this.controller,
    required this.focus,
    required this.hint,
    required this.icon,
    required this.maxLength,
    required this.inputFormatters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focus,
          keyboardType: TextInputType.number,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontFamily: 'monospace', letterSpacing: 1),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: Colors.white24, size: 18),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0065FF), width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(trimmed[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = trimmed.length > 2 ? '${trimmed.substring(0, 2)}/${trimmed.substring(2)}' : trimmed;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.orange, fontSize: 13))),
        ],
      ),
    );
  }
}
