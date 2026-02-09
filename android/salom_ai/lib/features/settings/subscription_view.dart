import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionView extends ConsumerStatefulWidget {
  const SubscriptionView({super.key});

  @override
  ConsumerState<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends ConsumerState<SubscriptionView> {
  String? _processingPlan;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(subscriptionManagerProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionManagerProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        title: Text(ref.tr('subscriptions')),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: subState.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPrimary))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  // Header
                  Column(
                    children: [
                      Text(ref.tr('pro_features'), style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(height: 8),
                      Text(ref.tr('unlimited_conv'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Current plan info
                  if (subState.isPro && subState.subscription != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration.copyWith(
                        border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subState.currentPlan?.toUpperCase() ?? 'PRO',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                if (subState.subscription!.expiresAt != null)
                                  Text(
                                    "${ref.tr('valid_until')}: ${subState.subscription!.expiresAt!.day}.${subState.subscription!.expiresAt!.month}.${subState.subscription!.expiresAt!.year}",
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.verified, color: AppTheme.accentPrimary, size: 28),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Plan cards
                  ...subState.plans.map((plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PlanCard(
                      plan: plan,
                      isCurrent: subState.currentPlan == plan.code && subState.isPro,
                      isProcessing: _processingPlan == plan.code,
                      locale: locale,
                      ref: ref,
                      onSubscribe: () => _handleSubscribe(plan.code),
                    ),
                  )),
                ],
              ),
      ),
    );
  }

  Future<void> _handleSubscribe(String planCode) async {
    setState(() => _processingPlan = planCode);
    final url = await ref.read(subscriptionManagerProvider.notifier).subscribe(planCode);
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    // Refresh status after returning from browser
    await Future.delayed(const Duration(seconds: 2));
    await ref.read(subscriptionManagerProvider.notifier).checkSubscriptionStatus();
    if (mounted) setState(() => _processingPlan = null);
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool isProcessing;
  final String locale;
  final WidgetRef ref;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isProcessing,
    required this.locale,
    required this.ref,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              if (plan.code == 'pro')
                const Icon(Icons.workspace_premium, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          Text("${plan.priceUzs} UZS",
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(ref.tr('month_count'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),

          const SizedBox(height: 16),
          if (plan.benefits != null)
            ...plan.benefits!.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, color: AppTheme.accentPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(benefit[locale] ?? benefit['uz'] ?? "",
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
                ],
              ),
            )),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isCurrent || plan.priceUzs == 0 || isProcessing)
                  ? null
                  : onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: (isCurrent || plan.priceUzs == 0)
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.accentPrimary,
                disabledBackgroundColor: Colors.white.withOpacity(0.05),
              ),
              child: isProcessing
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isCurrent
                      ? ref.tr('active')
                      : (plan.priceUzs == 0 ? ref.tr('free') : ref.tr('choose'))),
            ),
          ),
        ],
      ),
    );
  }
}
