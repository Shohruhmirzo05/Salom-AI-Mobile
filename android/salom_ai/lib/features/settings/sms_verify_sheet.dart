// SMS verification step of Click card tokenization. Reads 6-digit SMS code
// the user got on the phone tied to the card, sends it to backend to verify,
// save the card, and charge the first payment.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/constants/localization.dart';

class SmsVerifySheet extends ConsumerStatefulWidget {
  final String planCode;
  final String requestId;
  final String phoneHint;
  const SmsVerifySheet({
    super.key,
    required this.planCode,
    required this.requestId,
    required this.phoneHint,
  });

  @override
  ConsumerState<SmsVerifySheet> createState() => _SmsVerifySheetState();
}

class _SmsVerifySheetState extends ConsumerState<SmsVerifySheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  String? _error;

  static const _clickBlue = Color(0xFF0065FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = int.tryParse(_ctrl.text);
    if (code == null || _ctrl.text.length < 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(subscriptionManagerProvider.notifier).verifySms(
          requestId: widget.requestId,
          smsCode: code,
          planCode: widget.planCode,
        );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = ref.tr('sms_verify_error');
      });
      return;
    }
    // Pop back to where the paywall was opened from.
    Navigator.of(context).popUntil((route) => route.isFirst);
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
          r.tr('sms_verify_title'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.message_outlined, color: _clickBlue.withOpacity(0.85), size: 40),
              const SizedBox(height: 16),
              Text(
                widget.phoneHint.isNotEmpty
                    ? r.tr('sms_sent_to').replaceAll('%@', widget.phoneHint)
                    : r.tr('sms_sent_generic'),
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                r.tr('sms_tip'),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _verify(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontFamily: 'monospace',
                  letterSpacing: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: const TextStyle(color: Colors.white12, letterSpacing: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _clickBlue, width: 1.4),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
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
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.orange, fontSize: 13))),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (_ctrl.text.length < 4 || _loading) ? null : _verify,
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
                      : Text(r.tr('sms_verify_button'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
