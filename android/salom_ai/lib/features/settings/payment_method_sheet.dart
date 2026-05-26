// Minimal payment-method selector with trust signals (Click logo, lock).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/features/settings/card_input_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Method { oneTime, autoRenew }

class PaymentMethodSheet extends ConsumerStatefulWidget {
  final String planCode;
  const PaymentMethodSheet({super.key, required this.planCode});

  @override
  ConsumerState<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<PaymentMethodSheet> {
  _Method _selected = _Method.oneTime;
  bool _loading = false;
  String? _error;

  Future<void> _continue() async {
    setState(() => _error = null);
    if (_selected == _Method.autoRenew) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CardInputSheet(planCode: widget.planCode)),
      );
      return;
    }
    setState(() => _loading = true);
    final url = await ref
        .read(subscriptionManagerProvider.notifier)
        .subscribeOneTime(widget.planCode);
    if (!mounted) return;
    if (url == null) {
      setState(() {
        _loading = false;
        _error = ref.tr('payment_link_error');
      });
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) Navigator.of(context).pop();
    } else {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ref.tr('payment_link_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        title: Text(
          r.tr('payment'),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 150),
              children: [
                // Brand row: Salom → Click + SSL chip
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(
                        'assets/images/app_icon_transparent.png',
                        width: 28, height: 28,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 28, height: 28),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white24),
                    const SizedBox(width: 10),
                    Image.asset(
                      'assets/images/click_logo.png',
                      height: 18,
                      errorBuilder: (_, __, ___) => const Text(
                        'Click',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 10, color: Colors.white.withOpacity(0.45)),
                          const SizedBox(width: 4),
                          Text(
                            'SSL',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  r.tr('payment_method_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  r.tr('payment_method_subtitle'),
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 24),

                _Row(
                  active: _selected == _Method.oneTime,
                  icon: Icons.open_in_new_rounded,
                  title: r.tr('payment_one_time_title'),
                  subtitle: r.tr('payment_one_time_short'),
                  onTap: () => setState(() => _selected = _Method.oneTime),
                ),
                const SizedBox(height: 10),
                _Row(
                  active: _selected == _Method.autoRenew,
                  icon: Icons.autorenew_rounded,
                  title: r.tr('payment_auto_title'),
                  subtitle: r.tr('payment_auto_short'),
                  onTap: () => setState(() => _selected = _Method.autoRenew),
                ),

                const SizedBox(height: 18),
                // Trust strip
                Row(
                  children: [
                    _trustItem(Icons.lock_rounded, 'Xavfsiz'),
                    const SizedBox(width: 14),
                    _trustItem(Icons.verified_user_outlined, 'PCI DSS'),
                    const SizedBox(width: 14),
                    _trustItem(Icons.visibility_off_rounded, 'Maxfiy'),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97373).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFF97373)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFF97373), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Sticky CTA
            Positioned(
              left: 22, right: 22, bottom: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white.withOpacity(0.6),
                        disabledForegroundColor: Colors.black.withOpacity(0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  r.tr('continue'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: Colors.black.withOpacity(0.7)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 10, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 5),
                      Text(
                        r.tr('payment_security_note'),
                        style: const TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white.withOpacity(0.45)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Row({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.025),
          border: Border.all(
            color: active ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.06),
            width: active ? 1 : 0.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? Colors.white : Colors.white.withOpacity(0.2),
                  width: active ? 5 : 1,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: active ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: active ? Colors.white : Colors.white.withOpacity(0.55)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
