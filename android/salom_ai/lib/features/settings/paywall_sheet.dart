// Minimal premium paywall — Flutter / Android.
// Daily price as hero (cheap framing), monthly small. Includes app logo,
// mascot art, Click logo, trust strip, benefit checklist from API.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/features/settings/payment_method_sheet.dart';

Future<void> showPaywallSheet(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PaywallSheet(),
    ),
  );
}

class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({super.key});

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(subscriptionManagerProvider.notifier).loadAll();
      if (!mounted) return;
      final paid = _paidPlans;
      if (paid.isNotEmpty) {
        setState(() => _selectedCode = _recommended(paid)?.code);
      }
    });
  }

  List<SubscriptionPlan> get _paidPlans {
    final all = ref.read(subscriptionManagerProvider).plans;
    final paid = all.where((p) => p.priceUzs > 0).toList()
      ..sort((a, b) => a.priceUzs.compareTo(b.priceUzs));
    return paid;
  }

  SubscriptionPlan? _recommended(List<SubscriptionPlan> paid) {
    if (paid.length >= 2) return paid[1];
    return paid.isEmpty ? null : paid.first;
  }

  SubscriptionPlan? get _selectedPlan {
    final paid = _paidPlans;
    if (paid.isEmpty) return null;
    if (_selectedCode == null) return paid.first;
    return paid.firstWhere((p) => p.code == _selectedCode, orElse: () => paid.first);
  }

  Future<void> _continue() async {
    final plan = _selectedPlan;
    if (plan == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaymentMethodSheet(planCode: plan.code)),
    );
    await ref.read(subscriptionManagerProvider.notifier).checkSubscriptionStatus();
  }

  int _pricePerDay(SubscriptionPlan p) {
    final days = (p.durationDays ?? 30).clamp(1, 366);
    return (p.priceUzs / days).round();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionManagerProvider);
    final locale = ref.watch(localeProvider);
    final paid = state.plans.where((p) => p.priceUzs > 0).toList()
      ..sort((a, b) => a.priceUzs.compareTo(b.priceUzs));
    final recommendedCode = paid.length >= 2 ? paid[1].code : (paid.isEmpty ? null : paid.first.code);
    final selected = _selectedPlan;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Close button
            Positioned(
              top: 4, left: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 150),
              children: [
                // Mascot art
                Center(
                  child: Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/main_character.png',
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Brand row
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/app_icon_transparent.png',
                        width: 26, height: 26,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 26, height: 26),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Salom AI Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ref.tr('paywall_subtitle'),
                  style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 28),

                // Plan rows
                if (state.isLoading && paid.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                      ),
                    ),
                  )
                else
                  ...paid.map((plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DailyPriceRow(
                          plan: plan,
                          selected: (_selectedCode ?? recommendedCode) == plan.code,
                          recommended: plan.code == recommendedCode,
                          onTap: () => setState(() => _selectedCode = plan.code),
                          locale: locale,
                        ),
                      )),

                // Benefits checklist
                if (selected != null && selected.benefits != null && selected.benefits!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _BenefitsBlock(plan: selected, locale: locale),
                ],

                const SizedBox(height: 18),
                _TrustStrip(),
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
                      onPressed: selected == null ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white.withOpacity(0.4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: selected == null
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _t(locale, 'paywall_cta_start'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Text('·',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black.withOpacity(0.35),
                                    )),
                                const SizedBox(width: 6),
                                Text(
                                  '${_formatNum(_pricePerDay(selected))} ${_t(locale, 'per_day_short')}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ref.tr('paywall_footer'),
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
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

// --------------------------------------------------------------------------

class _DailyPriceRow extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;
  final String locale;

  const _DailyPriceRow({
    required this.plan,
    required this.selected,
    required this.recommended,
    required this.onTap,
    required this.locale,
  });

  String get _periodLabel {
    final days = plan.durationDays ?? 30;
    if (days == 30) return _t(locale, 'monthly_sub');
    if (days == 90) return _t(locale, 'quarterly_sub');
    if (days == 365) return _t(locale, 'yearly_sub');
    return '$days ${_t(locale, 'days')}';
  }

  String get _shortPeriod {
    final days = plan.durationDays ?? 30;
    if (days == 30) return _t(locale, 'period_month');
    if (days == 90) return _t(locale, 'period_3months');
    if (days == 365) return _t(locale, 'period_year');
    return '$days ${_t(locale, 'days')}';
  }

  int get _perDay {
    final days = (plan.durationDays ?? 30).clamp(1, 366);
    return (plan.priceUzs / days).round();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.025),
          border: Border.all(
            color: selected ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.06),
            width: selected ? 1 : 0.5,
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
                  color: selected ? Colors.white : Colors.white.withOpacity(0.2),
                  width: selected ? 5 : 1,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.name,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _t(locale, 'recommended_short'),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _periodLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // BIG daily price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatNum(_perDay),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _t(locale, 'uzs_per_day'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '${_formatNum(plan.priceUzs)} UZS / $_shortPeriod',
                  style: const TextStyle(color: Colors.white30, fontSize: 10.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsBlock extends StatelessWidget {
  final SubscriptionPlan plan;
  final String locale;
  const _BenefitsBlock({required this.plan, required this.locale});

  @override
  Widget build(BuildContext context) {
    final benefits = plan.benefits ?? const [];
    if (benefits.isEmpty) return const SizedBox.shrink();
    final short = locale.substring(0, 2).toLowerCase();
    final take = benefits.length < 6 ? benefits.length : 6;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${plan.name} ${_t(locale, 'benefits_title_suffix')}'.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(take, (i) {
            final row = benefits[i];
            final text = row[short] ?? row['uz'] ?? row['en'] ?? row.values.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _trustChip(Icons.lock_outline_rounded, 'Xavfsiz'),
        _trustChip(Icons.replay_rounded, 'Istalgan vaqt bekor'),
        _trustChip(Icons.verified_user_outlined, 'PCI DSS'),
        _clickChip(),
      ],
    );
  }

  Widget _trustChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _clickChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TO\'LOV',
            style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          ),
          const SizedBox(width: 7),
          Image.asset(
            'assets/images/click_logo.png',
            height: 14,
            errorBuilder: (_, __, ___) => const Text(
              'Click',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Helpers

String _formatNum(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _t(String locale, String key) {
  const map = <String, Map<String, String>>{
    'uz': {
      'monthly_sub': 'Oylik obuna',
      'quarterly_sub': '3 oylik obuna',
      'yearly_sub': 'Yillik obuna',
      'period_month': 'oy',
      'period_3months': '3 oy',
      'period_year': 'yil',
      'days': 'kun',
      'uzs_per_day': 'UZS / kun',
      'per_day_short': '/ kun',
      'recommended_short': 'Tavsiya',
      'benefits_title_suffix': 'imkoniyatlari',
      'paywall_cta_start': 'Boshlash',
    },
    'ru': {
      'monthly_sub': 'Ежемесячно',
      'quarterly_sub': 'Каждые 3 мес.',
      'yearly_sub': 'Ежегодно',
      'period_month': 'мес',
      'period_3months': '3 мес',
      'period_year': 'год',
      'days': 'дн.',
      'uzs_per_day': 'UZS / день',
      'per_day_short': '/ день',
      'recommended_short': 'Хит',
      'benefits_title_suffix': '— что входит',
      'paywall_cta_start': 'Начать',
    },
    'en': {
      'monthly_sub': 'Monthly',
      'quarterly_sub': 'Quarterly',
      'yearly_sub': 'Yearly',
      'period_month': 'mo',
      'period_3months': '3 mo',
      'period_year': 'yr',
      'days': 'days',
      'uzs_per_day': 'UZS / day',
      'per_day_short': '/ day',
      'recommended_short': 'Top',
      'benefits_title_suffix': "— what's included",
      'paywall_cta_start': 'Start',
    },
    'uz-Cyrl': {
      'monthly_sub': 'Ойлик обуна',
      'quarterly_sub': '3 ойлик обуна',
      'yearly_sub': 'Йиллик обуна',
      'period_month': 'ой',
      'period_3months': '3 ой',
      'period_year': 'йил',
      'days': 'кун',
      'uzs_per_day': 'UZS / кун',
      'per_day_short': '/ кун',
      'recommended_short': 'Тавсия',
      'benefits_title_suffix': 'имкониятлари',
      'paywall_cta_start': 'Бошлаш',
    },
  };
  return map[locale]?[key] ?? map['uz']![key] ?? key;
}
